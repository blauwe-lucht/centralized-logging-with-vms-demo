use actix_web::{web, App, HttpServer, HttpResponse, Responder, HttpRequest};
use serde::{Deserialize, Serialize};
use tracing::{info, debug, warn};
use tracing_subscriber::EnvFilter;
use uuid::Uuid;

// Struct to handle the incoming JSON request
#[derive(Debug, Deserialize)]
struct FibonacciRequest {
    number: i32,
}

// Struct to send the Fibonacci result as a JSON response
#[derive(Debug, Serialize)]
struct FibonacciResponse {
    number: i32,
    result: i64,
    request_id: String,
}

// Function to calculate the Fibonacci number
fn fibonacci(n: i32) -> i64 {
    match n {
        0 => 0,
        1 => 1,
        _ => {
            let mut a = 0;
            let mut b = 1;
            for _ in 2..=n {
                let temp = a + b;
                a = b;
                b = temp;
            }
            b
        }
    }
}

// Handler to process Fibonacci requests
async fn fibonacci_handler(req_body: web::Json<FibonacciRequest>, req: HttpRequest) -> impl Responder {
    let request_id = req
        .headers()
        .get("X-Request-ID")
        .map(|v| v.to_str().unwrap_or_default().to_string())
        .unwrap_or_else(|| Uuid::new_v4().to_string());

    let number = req_body.number;
    debug!(request_id = request_id.as_str(), number = number, "Received Fibonacci request");

    if number < 0 {
        warn!(request_id = request_id.as_str(), "Invalid Fibonacci number: {}", number);
        return HttpResponse::BadRequest().json(format!("Invalid number: {}", number));
    }

    let result = fibonacci(number);
    info!(request_id = request_id.as_str(), number = number, result = result, "Fibonacci result calculated");

    let response = FibonacciResponse {
        number,
        result,
        request_id,
    };

    HttpResponse::Ok().json(response)
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    // Initialize logging
    tracing_subscriber::fmt()
        .json()  // Use JSON format for structured logging
        .with_max_level(tracing::Level::INFO)
        .with_env_filter(EnvFilter::from_default_env())
        .init();

    info!("Fibonacci Backend started");

    // Start the Actix web server
    HttpServer::new(|| {
        App::new()
            .route("/fibonacci", web::post().to(fibonacci_handler))  // POST /fibonacci
    })
        .bind("127.0.0.1:5000")?  // Listen on port 5000
        .run()
        .await
}
