#include "crow.h"
#include "spdlog/spdlog.h"
#include "spdlog/sinks/basic_file_sink.h"

// Function to calculate the Fibonacci number
int fibonacci(int n) {
    if (n <= 1)
        return n;
    return fibonacci(n - 1) + fibonacci(n - 2);
}

int main() {
    auto logger = spdlog::basic_logger_mt("fibonacci_backend", "/var/log/fibonacci/application.log");
    spdlog::set_default_logger(logger);
    spdlog::set_level(spdlog::level::debug);
    spdlog::flush_every(std::chrono::seconds(1));
    spdlog::info("Fibonacci Backend started");
    
    // Initialize the HTTP server
    crow::SimpleApp app;

    // Define the route for Fibonacci calculation
    CROW_ROUTE(app, "/fibonacci/<int>")([&](const crow::request& req, int number) {
        std::string request_id = req.get_header_value("X-Request-ID");
        if (request_id.empty()) {
            request_id = "unknown";
        }

        spdlog::info("/fibonacci [{}] - Received request to calculate Fibonacci for number: {}", request_id, number);
        
        int result = fibonacci(number);

        spdlog::info("/fibonacci [{}] - Fibonacci result for {} is {}", request_id, number, result);

        crow::json::wvalue response;
        response["number"] = number;
        response["result"] = result;

        return response;
    });

    spdlog::info("Fibonacci Backend starting on port 5000...");
    app.port(5000).multithreaded().run();

    spdlog::info("Fibonacci Backend finished");
    return 0;
}
