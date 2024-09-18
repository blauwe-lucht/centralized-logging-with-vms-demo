use serde::{Deserialize, Serialize};
use std::io::Read;
use tracing::{info, debug, warn, Level};
use tracing_subscriber::EnvFilter;
use tracing_appender::rolling::{RollingFileAppender, Rotation};
use rouille::{router, Request, Response};

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
fn calculate_fibonacci(n: i32) -> i64 {
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

fn extract_request_id(request: &Request) -> String {
    const REQUEST_ID_HEADER: &str = "X-Request-ID";
    if let Some(header) = request.header(REQUEST_ID_HEADER) {
        debug!(request_id = %header, "Request ID found in headers");
        header.to_string()
    } else {
        let new_request_id = "unknown";
        warn!(request_id = %new_request_id, "No Request ID found in headers, using 'unknown'");
        new_request_id.to_string()
    }
}

fn handle_fibonacci_request(request: &Request) -> Response {
    info!(function = "handle_fibonacci_request", "Start");

    let request_id = extract_request_id(request);

    let body: String = match extract_request_body_text(request) {
        Ok(value) => value,
        Err(value) => return value,
    };

    let fib_request: FibonacciRequest = match parse_body_text(&body) {
        Ok(value) => value,
        Err(value) => return value,
    };

    debug!(request_id = request_id, number = fib_request.number, "Calculating Fibonacci");

    let result = calculate_fibonacci(fib_request.number);
    let fib_response = FibonacciResponse {
        number: fib_request.number,
        result,
        request_id: request_id.clone(),
    };

    info!(request_id = %request_id, result = result, "Fibonacci result calculated");

    Response::json(&fib_response)
}

fn parse_body_text(body: &String) -> Result<FibonacciRequest, Response> {
    let fib_request: FibonacciRequest = match serde_json::from_str(&body) {
        Ok(req) => req,
        Err(err) => {
            warn!(function = "handle_fibonacci_request", body = body, error = %err, "Invalid JSON in request");
            return Err(Response::text("Invalid JSON").with_status_code(400));
        }
    };
    Ok(fib_request)
}

fn extract_request_body_text(request: &Request) -> Result<String, Response> {
    let mut body = String::new();
    if let Some(mut data) = request.data() {
        if let Err(err) = data.read_to_string(&mut body) {
            warn!(function = "handle_fibonacci_request", error = %err, "Failed to read request body");
            return Err(Response::text("Failed to read request body").with_status_code(400));
        }
    } else {
        warn!(function = "handle_fibonacci_request", "No request body found");
        return Err(Response::text("No request body found").with_status_code(400));
    }
    Ok(body)
}

fn main(){
    let file_appender = RollingFileAppender::new(Rotation::DAILY,
                                                 "/var/log/fibonacci",
                                                 "backend");
    tracing_subscriber::fmt()
        .json()  // Output logs as JSON
        .with_writer(file_appender)
        .with_env_filter(EnvFilter::from_default_env())
        .with_max_level(Level::DEBUG)
        .init();

    info!("Fibonacci Backend started");

    rouille::start_server("127.0.0.1:5000", move |request| {
        router!(request,
            (GET) ["/"] => {
                Response::text("Fibonacci API")
            },
            (GET) ["/fibonacci"] => {
                handle_fibonacci_request(request)
            },
            _ => Response::empty_404()
        )
    });
}
