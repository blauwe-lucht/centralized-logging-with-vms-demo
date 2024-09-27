use serde::{Deserialize, Serialize};
use std::fs::File;
use std::io::Read;
use tracing::{info, debug, warn, Level, error};
use tracing_subscriber::EnvFilter;
use tracing_appender::rolling::{RollingFileAppender, Rotation};
use rouille::{router, Request, Response};
use serde_json::json;

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

// Helper function to read a file's contents
fn read_file(file_path: &str) -> Option<String> {
    let function = "read_file";
    debug!(function, file_path, "Enter");

    let mut file = match File::open(file_path) {
        Ok(file) => file,
        Err(_) => {
            warn!(function, file_path, "File not found");
            return None;
        }
    };

    let mut contents = String::new();
    if file.read_to_string(&mut contents).is_ok() {
        debug!(function, file_path, "Read file successful");
        Some(contents)
    } else {
        warn!(function, file_path, "Failed to read file");
        None
    }
}

fn send_fibonacci_request(number: i32, request_id: &str) -> Result<FibonacciResponse, Box<dyn std::error::Error>> {
    let function = "send_fibonacci_request";
    let backend_url = "http://192.168.6.32/fibonacci";
    debug!(function, request_id, backend_url, number, "Sending request");

    let payload = json!({
        "number": number
    });

    let response = attohttpc::get(backend_url)
        .header("X-Request-ID", request_id)
        .json(&payload)?
        .send()?;

    let response_text = response.text()?;
    debug!(function, request_id, backend_response = response_text.as_str(), "Response received");

    let fib_response: FibonacciResponse = serde_json::from_str(&response_text)?;
    debug!(function, request_id, answer = fib_response.result, "Answer received");

    Ok(fib_response)
}

fn extract_request_id(request: &Request) -> String {
    const REQUEST_ID_HEADER: &str = "X-Request-ID";
    if let Some(request_id) = request.header(REQUEST_ID_HEADER) {
        debug!(request_id = %request_id, "Request ID found in headers");
        request_id.to_string()
    } else {
        let request_id = "unknown";
        warn!(request_id = %request_id, "No Request ID found in headers, using 'unknown'");
        request_id.to_string()
    }
}

fn handle_fibonacci_request(request: &Request) -> Response {
    let function = "handle_fibonacci_request";
    let request_id = extract_request_id(request);
    debug!(function, request_id, "Enter");

    // Read the request body (JSON payload)
    let mut body = String::new();
    if let Some(mut data) = request.data() {
        if let Err(err) = data.read_to_string(&mut body) {
            error!(error = %err, function, request_id, "Failed to read request body");
            return Response::text("Failed to read request body").with_status_code(400);
        }
    } else {
        error!(function, request_id, "No request body found");
        return Response::text("No request body found").with_status_code(400);
    }

    // Parse the JSON body
    let fib_request: FibonacciRequest = match serde_json::from_str(&body) {
        Ok(fib_request) => fib_request,
        Err(err) => {
            error!(error = %err, function, request_id, "Invalid JSON");
            return Response::text("Invalid JSON").with_status_code(400)
        },
    };

    // Send the request to the backend
    match send_fibonacci_request(fib_request.number, request_id.as_str()) {
        Ok(fib_response) => {
            // Convert the response to JSON and return it
            let response_json = serde_json::to_string(&fib_response).unwrap();
            Response::text(response_json)
                .with_additional_header("Content-Type", "application/json")
        }
        Err(error) => {
            error!(error = %error, function, request_id, "Failed to send fibonacci request");
            Response::text("Failed to contact backend").with_status_code(500)
        },
    }
}

fn main() {
    let file_appender = RollingFileAppender::new(Rotation::DAILY,
                                                 "/var/log/fibonacci",
                                                 "frontend");
    tracing_subscriber::fmt()
        .json()
        .flatten_event(true)// Put fields at the root level
        .with_writer(file_appender)
        .with_env_filter(EnvFilter::from_default_env())
        .with_max_level(Level::DEBUG)
        .init();

    info!("Fibonacci Frontend started");

    rouille::start_server("127.0.0.1:8080", move |request| {
        router!(request,
            (GET) ["/"] => {
                if let Some(file_contents) = read_file("index.html") {
                    Response::html(file_contents)
                }
                else {
                    Response::empty_404()
                }
            },
            (POST) ["/fibonacci"] => {
                handle_fibonacci_request(request)
            },
            _ => Response::empty_404()  // Return 404 for any other route
        )
    });
}
