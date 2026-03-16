import Foundation

// MARK: - Chat Completion

struct ChatMessage: Codable, Sendable {
    let role: String
    let content: String
}

struct ChatCompletionRequest: Codable, Sendable {
    let model: String
    let messages: [ChatMessage]
    let temperature: Double?
    let maxTokens: Int?
    let stream: Bool?

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature, stream
        case maxTokens = "max_tokens"
    }
}

struct ChatCompletionChoice: Codable, Sendable {
    let index: Int
    let message: ChatMessage?
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case index
        case message
        case finishReason = "finish_reason"
    }
}

struct ChatCompletionResponse: Codable, Sendable {
    let id: String
    let choices: [ChatCompletionChoice]
}

struct ChatCompletionChunkDelta: Codable, Sendable {
    let role: String?
    let content: String?
}

struct ChatCompletionChunkChoice: Codable, Sendable {
    let index: Int
    let delta: ChatCompletionChunkDelta
    let finishReason: String?

    enum CodingKeys: String, CodingKey {
        case index
        case delta
        case finishReason = "finish_reason"
    }
}

struct ChatCompletionChunk: Codable, Sendable {
    let id: String
    let choices: [ChatCompletionChunkChoice]
}

// MARK: - Audio Transcription

struct TranscriptionResponse: Codable, Sendable {
    let text: String
}

struct TranscriptionStreamDelta: Codable, Sendable {
    let type: String
    let delta: String?
}

// MARK: - Error

struct OpenAIErrorResponse: Codable, Sendable {
    let error: OpenAIErrorDetail
}

struct OpenAIErrorDetail: Codable, Sendable {
    let message: String
    let type: String?
    let code: String?
}

// MARK: - Client

final class OpenAIClient: Sendable {
    let baseURL: String
    let apiKey: String
    let session: URLSession

    init(baseURL: String, apiKey: String) {
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.apiKey = apiKey
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 600
        self.session = URLSession(configuration: config)
    }

    // MARK: - Chat Completion (non-streaming)

    func chatCompletion(
        model: String,
        messages: [ChatMessage],
        temperature: Double = 0.7,
        maxTokens: Int = 1024
    ) async throws -> String {
        let request = ChatCompletionRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens,
            stream: false
        )

        let body = try JSONEncoder().encode(request)
        let urlRequest = makeRequest(path: "/chat/completions", body: body)
        let (data, response) = try await session.data(for: urlRequest)
        try validateHTTPResponse(response, data: data)

        let completion = try JSONDecoder().decode(ChatCompletionResponse.self, from: data)
        return completion.choices.first?.message?.content ?? ""
    }

    // MARK: - Chat Completion (streaming)

    func chatCompletionStream(
        model: String,
        messages: [ChatMessage],
        temperature: Double = 0.7,
        maxTokens: Int = 1024,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        let request = ChatCompletionRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens,
            stream: true
        )

        let body = try JSONEncoder().encode(request)
        let urlRequest = makeRequest(path: "/chat/completions", body: body)
        let (bytes, response) = try await session.bytes(for: urlRequest)
        try validateHTTPResponse(response, data: nil)

        var accumulated = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            if payload == "[DONE]" { break }

            guard let chunkData = payload.data(using: .utf8),
                  let chunk = try? JSONDecoder().decode(ChatCompletionChunk.self, from: chunkData),
                  let delta = chunk.choices.first?.delta.content
            else { continue }

            accumulated += delta
            onDelta(delta)
        }

        return accumulated
    }

    // MARK: - Audio Transcription (non-streaming, file upload)

    func transcribeAudio(
        model: String,
        audioData: Data,
        language: String? = nil,
        prompt: String? = nil
    ) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        appendFormField(&body, boundary: boundary, name: "model", value: model)
        appendFormField(&body, boundary: boundary, name: "response_format", value: "json")

        if let language, !language.isEmpty {
            appendFormField(&body, boundary: boundary, name: "language", value: language)
        }

        if let prompt, !prompt.isEmpty {
            appendFormField(&body, boundary: boundary, name: "prompt", value: prompt)
        }

        appendFormFile(&body, boundary: boundary, name: "file", filename: "audio.wav", mimeType: "audio/wav", data: audioData)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var urlRequest = makeRequest(path: "/audio/transcriptions", body: nil)
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = body

        let (data, response) = try await session.data(for: urlRequest)
        try validateHTTPResponse(response, data: data)

        // Try standard OpenAI format first, then fall back to plain text or other formats
        if let transcription = try? JSONDecoder().decode(TranscriptionResponse.self, from: data) {
            return transcription.text
        }

        // Some servers return {"text": "..."} with extra fields, or just a string
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let text = json["text"] as? String {
            return text
        }

        // Last resort: treat response as plain text
        if let text = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !text.isEmpty {
            return text
        }

        throw OpenAIClientError.apiError(statusCode: 200, message: "Empty transcription response")
    }

    // MARK: - Audio Transcription (streaming)

    func transcribeAudioStream(
        model: String,
        audioData: Data,
        language: String? = nil,
        onDelta: @escaping @Sendable (String) -> Void
    ) async throws -> String {
        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()

        appendFormField(&body, boundary: boundary, name: "model", value: model)
        appendFormField(&body, boundary: boundary, name: "response_format", value: "json")
        appendFormField(&body, boundary: boundary, name: "stream", value: "true")

        if let language, !language.isEmpty {
            appendFormField(&body, boundary: boundary, name: "language", value: language)
        }

        appendFormFile(&body, boundary: boundary, name: "file", filename: "audio.wav", mimeType: "audio/wav", data: audioData)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)

        var urlRequest = makeRequest(path: "/audio/transcriptions", body: nil)
        urlRequest.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = body

        let (bytes, response) = try await session.bytes(for: urlRequest)
        try validateHTTPResponse(response, data: nil)

        var accumulated = ""
        for try await line in bytes.lines {
            guard line.hasPrefix("data: ") else { continue }
            let payload = String(line.dropFirst(6))
            if payload == "[DONE]" { break }

            guard let deltaData = payload.data(using: .utf8),
                  let delta = try? JSONDecoder().decode(TranscriptionStreamDelta.self, from: deltaData),
                  let text = delta.delta
            else { continue }

            accumulated += text
            onDelta(text)
        }

        return accumulated
    }

    // MARK: - Helpers

    private func makeRequest(path: String, body: Data?) -> URLRequest {
        let url = URL(string: baseURL + path)!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        // Only set auth header if an API key is provided and not a placeholder
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty && trimmedKey != "not-needed" && trimmedKey != "none" {
            request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        }
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        return request
    }

    private func validateHTTPResponse(_ response: URLResponse, data: Data?) throws {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIClientError.invalidResponse
        }

        guard (200 ... 299).contains(httpResponse.statusCode) else {
            var message = "HTTP \(httpResponse.statusCode)"
            if let data, let errorResponse = try? JSONDecoder().decode(OpenAIErrorResponse.self, from: data) {
                message = errorResponse.error.message
            }
            throw OpenAIClientError.apiError(statusCode: httpResponse.statusCode, message: message)
        }
    }

    private func appendFormField(_ body: inout Data, boundary: String, name: String, value: String) {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n".data(using: .utf8)!)
        body.append("\(value)\r\n".data(using: .utf8)!)
    }

    private func appendFormFile(_ body: inout Data, boundary: String, name: String, filename: String, mimeType: String, data: Data) {
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n".data(using: .utf8)!)
    }
}

enum OpenAIClientError: Error, LocalizedError {
    case invalidResponse
    case apiError(statusCode: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from OpenAI API"
        case .apiError(let statusCode, let message):
            return "OpenAI API error (\(statusCode)): \(message)"
        }
    }
}
