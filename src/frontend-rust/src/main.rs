use actix_web::{web, App, HttpServer, HttpResponse, Responder};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use std::fs::File;
use std::io::Read;
use uuid::Uuid;
use tracing::{info, debug, warn, Level};
use tracing_subscriber::EnvFilter;
use tracing_appender::rolling::{RollingFileAppender, Rotation};
use std::sync::Arc;

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
            warn!(file_path = file_path, "File not found");
            return None;
        }
    };

    let mut contents = String::new();
    if file.read_to_string(&mut contents).is_ok() {
        info!(file_path = file_path, "Read file");
        Some(contents)
    } else {
        warn!(file_path = file_path, "Failed to read file");
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
            debug!(html_length = html.len(), "Serving index.html");
            HttpResponse::Ok().body(html)
        },
        None => HttpResponse::NotFound().body("File not found"),
    }
}

// Handler to process Fibonacci requests
async fn fibonacci_handler(req_body: web::Json<FibonacciRequest>, client: web::Data<Arc<Client>>) -> impl Responder {
    let request_id = generate_request_id();
    let number = req_body.number;

    info!(request_id = request_id.as_str(), number = number, "Received request for Fibonacci number");

    let url = format!("http://192.168.6.32:5000/fibonacci/{}", number);
    debug!(request_id = request_id.as_str(), url = url.as_str(), "Sending request to backend");

    match send_fibonacci_request(&client, &url, &request_id).await {
        Ok(fib_response) => {
            debug!(request_id = request_id.as_str(), ?fib_response, "Received response from backend");
            HttpResponse::Ok().json(fib_response)
        },
        Err(err) => {
            warn!(request_id = request_id.as_str(), error = %err, "Error contacting backend");
            HttpResponse::InternalServerError().body("Failed to contact Fibonacci microservice")
        }
    }
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // Create a file appender for logging to /var/log/fibonacci/application.log
    let file_appender = RollingFileAppender::new(Rotation::DAILY,
                                                 "/var/log/fibonacci",
                                                 "application");

    // Set up `tracing-subscriber` to log structured logs in JSON format
    tracing_subscriber::fmt()
        .json()  // Output logs as JSON
        .with_writer(file_appender)
        .with_env_filter(EnvFilter::from_default_env())
        .with_max_level(Level::DEBUG)
        .init();

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
