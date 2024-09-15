#include "crow.h"
#include "spdlog/spdlog.h"
#include "spdlog/sinks/basic_file_sink.h"
#include <fstream>
#include <uuid/uuid.h>
#include <curl/curl.h>

// Generate a unique request ID
std::string generaterequest_id() {
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

std::string send_fibonacci_request(const std::string& url, const std::string& request_id) {
    CURL* curl;
    CURLcode res;
    std::string response_data;

    curl = curl_easy_init();
    if (curl) {
        // Set URL and headers
        curl_easy_setopt(curl, CURLOPT_URL, url.c_str());

        struct curl_slist* headers = NULL;
        headers = curl_slist_append(headers, ("X-Request-ID: " + request_id).c_str());
        curl_easy_setopt(curl, CURLOPT_HTTPHEADER, headers);

        // Define a callback to capture the response body
        curl_easy_setopt(curl, CURLOPT_WRITEFUNCTION, [](char* data, size_t size, size_t nmemb, std::string* buffer) {
            if (buffer) {
                buffer->append(data, size * nmemb);
                return size * nmemb;
            }
            return static_cast<size_t>(0);
        });

        curl_easy_setopt(curl, CURLOPT_WRITEDATA, &response_data);

        // Perform the request
        res = curl_easy_perform(curl);

        // Clean up
        curl_slist_free_all(headers);
        curl_easy_cleanup(curl);
    }
    return response_data;
}

int main() {
    auto file_logger = spdlog::basic_logger_mt("fibonacci_frontend", "/var/log/fibonacci/application.log");
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
        auto request_id = generaterequest_id();

        auto json_data = crow::json::load(req.body);
        if (!json_data) {
            spdlog::debug("/fibonacci: invalid input data {}", req.body);
            return crow::response(400, "Invalid input");
        }

        spdlog::info("/fibonacci [{}] Starting request", request_id);

        int number = json_data["number"].i();
        spdlog::info("/fibonacci [{}] Requesting Fibonacci calculation for number: {}", request_id, number);

        auto url = "http://192.168.6.32:5000/fibonacci/" + std::to_string(number);
        spdlog::debug("/fibonacci [{}] using url {}", request_id, url);

        std::string microservice_response = send_fibonacci_request(url, request_id);

        spdlog::debug("/fibonacci [{}] Received response from microservice: {}", request_id, microservice_response);
        return crow::response(microservice_response);
    });

    spdlog::info("Starting backend server...");
    app.port(8080).multithreaded().run();

    spdlog::info("Fibonacci Frontend finished");
}
