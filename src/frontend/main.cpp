#include "crow.h"
#include "spdlog/spdlog.h"
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
        return std::string((std::istreambuf_iterator<char>(file)), std::istreambuf_iterator<char>());
    }
    return "";
}

int main() {
    crow::SimpleApp app;

    // Route to serve the HTML file for the frontend
    CROW_ROUTE(app, "/")
    ([]() {
        spdlog::info("Serving frontend HTML file.");
        std::string html = readFile("index.html");  // Make sure this path is correct
        if (html.empty()) {
            return crow::response(404, "File not found");
        }
        return crow::response(html);
    });

    // API route to handle Fibonacci requests
    CROW_ROUTE(app, "/fibonacci").methods("POST"_method)
    ([](const crow::request& req) {
        auto requestID = generateRequestID();
        spdlog::info("Received request with ID: {}", requestID);

        auto json_data = crow::json::load(req.body);
        if (!json_data) {
            return crow::response(400, "Invalid input");
        }

        int number = json_data["number"].i();
        spdlog::info("[{}] Requesting Fibonacci calculation for number: {}", requestID, number);

        // Forward request to microservice (Replace with real service call)
        crow::response microservice_response = crow::response(200, "{\"result\": \"42\"}");

        spdlog::info("[{}] Received response from microservice: {}", requestID, microservice_response.body);
        return crow::response(microservice_response.body);
    });

    spdlog::info("Starting backend server...");
    app.port(8080).multithreaded().run();
}
