#include "crow.h"
#include "spdlog/spdlog.h"
#include "spdlog/sinks/basic_file_sink.h"
#include <fstream>
#include <uuid/uuid.h>

// Generate a unique request ID
std::string generateRequestID() {
    uuid_t uuid;
    uuid_generate(uuid);
    char uuid_str[37];
    uuid_unparse(uuid, uuid_str);
    return std::string(uuid_str);
}

// Function to read a file (used for serving HTML)
std::string readFile(const std::string& filePath) {
    std::ifstream file(filePath);
    if (file) {
        spdlog::info("Reading file {}", filePath);
        return std::string((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    }
    spdlog::warn("Trying to read non-existint file {}", filePath);
    return "";
}

int main() {
    auto file_logger = spdlog::basic_logger_mt("file_logger", "/var/log/fibonacci/application.log");
    spdlog::set_default_logger(file_logger);
    spdlog::set_level(spdlog::level::debug);
    spdlog::flush_every(std::chrono::seconds(1));
    spdlog::info("Fibonacci Frontend started");

    crow::SimpleApp app;

    // Route to serve the HTML file for the frontend
    CROW_ROUTE(app, "/")
    ([]() {
        spdlog::info("Serving frontend HTML file.");
        std::string html = readFile("index.html");  // Make sure this path is correct
        if (html.empty()) {
            return crow::response(404, "File not found");
        }
        spdlog::debug("Returning html of length {}", html.length());
        return crow::response(html);
    });

    // API route to handle Fibonacci requests
    CROW_ROUTE(app, "/fibonacci").methods("POST"_method)
    ([](const crow::request& req) {
        auto requestID = generateRequestID();

        auto json_data = crow::json::load(req.body);
        if (!json_data) {
            spdlog::debug("/fibonacci: invalid input data {}", req.body);
            return crow::response(400, "Invalid input");
        }

        spdlog::info("/fibonacci [{}] Starting request", requestID);

        int number = json_data["number"].i();
        spdlog::info("/fibonacci [{}] Requesting Fibonacci calculation for number: {}", requestID, number);

        // Forward request to microservice (Replace with real service call)
        crow::response microservice_response = crow::response(200, "{\"result\": \"42\"}");

        spdlog::debug("/fibonacci [{}] Received response from microservice: {}", requestID, microservice_response.body);
        return crow::response(microservice_response.body);
    });

    spdlog::info("Starting backend server...");
    app.port(8080).multithreaded().run();

    spdlog::info("Fibonacci Frontend finished");
}
