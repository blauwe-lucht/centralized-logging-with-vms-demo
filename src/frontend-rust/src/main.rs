use actix_web::{web, App, HttpServer, HttpResponse, Responder};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::fs::File;
use std::io::Read;
use uuid::Uuid;
use log::{info, debug, warn};
use std::sync::Arc;
use flexi_logger::{Logger, WriteMode, Age, Cleanup, Criterion, FileSpec, Naming};

// Struct to handle JSON input
#[derive(Debug, Deserialize)]
struct FibonacciRequest {
    number: i32,
}

// Struct to deserialize the microservice's response
#[derive(Debug, Serialize, Deserialize)]
struct FibonacciResponse {
    number: i32,
    result: i64,
    request_id: String,
}

// Helper function to generate a UUID
fn generate_request_id() -> String {
    Uuid::new_v4().to_string()
}

// Helper function to read a file's contents
fn read_file(file_path: &str) -> Option<String> {
    let mut file = match File::open(file_path) {
        Ok(file) => file,
        Err(_) => {
            warn!("File not found: {}", file_path);
            return None;
        }
    };

    let mut contents = String::new();
    if file.read_to_string(&mut contents).is_ok() {
        info!("Read file: {}", file_path);
        Some(contents)
    } else {
        warn!("Failed to read file: {}", file_path);
        None
    }
}

// Function to handle the Fibonacci request to the backend microservice
async fn send_fibonacci_request(client: &Client, url: &str, request_id: &str) -> Result<FibonacciResponse, reqwest::Error> {
    let response = client
        .get(url)
        .header("X-Request-ID", request_id)
        .send()
        .await?
        .json::<FibonacciResponse>()
        .await?;

    Ok(response)
}

// Handler to serve the HTML frontend
async fn index() -> impl Responder {
    match read_file("index.html") {
        Some(html) => {
            debug!("Serving index.html with length: {}", html.len());
            HttpResponse::Ok().body(html)
        },
        None => HttpResponse::NotFound().body("File not found"),
    }
}

// Handler to process Fibonacci requests
async fn fibonacci_handler(req_body: web::Json<FibonacciRequest>, client: web::Data<Arc<Client>>) -> impl Responder {
    let request_id = generate_request_id();
    let number = req_body.number;

    info!("[{}] Received request for Fibonacci number: {}", request_id, number);

    let url = format!("http://192.168.6.32:5000/fibonacci/{}", number);
    debug!("[{}] Using URL: {}", request_id, url);

    match send_fibonacci_request(&client, &url, &request_id).await {
        Ok(fib_response) => {
            debug!("[{}] Microservice response: {:?}", request_id, fib_response);
            HttpResponse::Ok().json(fib_response)
        },
        Err(err) => {
            warn!("[{}] Error contacting microservice: {}", request_id, err);
            HttpResponse::InternalServerError().body("Failed to contact Fibonacci microservice")
        }
    }
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // Initialize logging
    Logger::try_with_str("debug").unwrap()
        .log_to_file(FileSpec::default().directory("/var/log/fibonacci"))
        .format(flexi_logger::detailed_format)  // Use detailed format with timestamps
        .write_mode(WriteMode::Direct)
        .rotate(
            Criterion::Age(Age::Day),
            Naming::Timestamps,
            Cleanup::KeepLogFiles(7),
        )
        .duplicate_to_stdout(flexi_logger::Duplicate::Warn)
        .start().unwrap();
    info!("Fibonacci Frontend started");

    // Create an HTTP client instance
    let client = Arc::new(Client::new());

    // Start the Actix web server
    HttpServer::new(move || {
        App::new()
            .app_data(web::Data::new(client.clone()))
            .route("/", web::get().to(index))
            .route("/fibonacci", web::post().to(fibonacci_handler))
    })
    .bind("127.0.0.1:8080")?
    .run()
    .await?;

    Ok(())
}
