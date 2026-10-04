require "base64"
require "json"
require "net/http"
require "uri"

class CohereChat
  class Error < StandardError; end

  ENDPOINT = URI("https://api.cohere.com/v2/chat")
  DEFAULT_MODEL = "command-a-03-2025"
  DEFAULT_MAX_OUTPUT_TOKENS = 2_000
  MAX_ATTEMPTS = 3
  MAX_IMAGE_BYTES = 20.megabytes
  MAX_TOTAL_DOCUMENT_CHARS = 200_000

  def self.call(prompt, attachments: [])
    new.call(prompt, attachments: attachments)
  end

  def call(prompt, attachments: [])
    api_key = ENV["COHERE_API_KEY"].to_s.strip
    raise Error, "Cohere is not configured. Set COHERE_API_KEY and try again." if api_key.empty?

    documents = []
    content = []
    total_document_chars = 0
    requested_prompt = prompt.to_s.strip
    requested_prompt = default_prompt if requested_prompt.empty?

    content << { "type" => "text", "text" => requested_prompt }

    image_bytes = 0
    Array(attachments).each_with_index do |attachment, index|
      next unless attachment.is_a?(Hash)

      if image_attachment?(attachment) && image_bytes + attachment["size"].to_i <= MAX_IMAGE_BYTES
        data_url = image_data_url(attachment)
        if data_url
          content << {
            "type" => "image_url",
            "image_url" => { "url" => data_url, "detail" => "auto" }
          }
          image_bytes += attachment["size"].to_i
        end
      end

      extracted = AttachmentReader.read(attachment)
      next if extracted.blank?
      remaining_chars = MAX_TOTAL_DOCUMENT_CHARS - total_document_chars
      next if remaining_chars <= 0

      extracted = extracted[0, remaining_chars]
      documents << {
        "id" => "file_#{index + 1}",
        "data" => {
          "title" => attachment["name"].to_s,
          "text" => extracted
        }
      }
      total_document_chars += extracted.length
    end

    if content.length == 1 && documents.empty? && attachments.any?
      content << {
        "type" => "text",
        "text" => "The uploaded file is stored with the chat, but its contents could not be extracted by the server. Explain what can still be done and what file format would be needed for content analysis."
      }
    end

    selected_model = if content.any? { |item| item.is_a?(Hash) && item["type"] == "image_url" }
      ENV.fetch("COHERE_VISION_MODEL", ENV.fetch("COHERE_MODEL", "command-a-vision-07-2025"))
    else
      ENV.fetch("COHERE_MODEL", DEFAULT_MODEL)
    end

    request_body = {
      model: selected_model,
      messages: [{ role: "user", content: content }],
      max_tokens: ENV.fetch("COHERE_MAX_OUTPUT_TOKENS", DEFAULT_MAX_OUTPUT_TOKENS).to_i
    }
    request_body[:documents] = documents if documents.any?

    request = Net::HTTP::Post.new(ENDPOINT)
    request["Authorization"] = "Bearer #{api_key}"
    request["Content-Type"] = "application/json"
    request["Accept"] = "application/json"
    request.body = request_body.to_json

    response = request_with_retries(request)
    payload = JSON.parse(response.body)
    raise Error, error_message(payload, response.code) unless response.is_a?(Net::HTTPSuccess)

    text = Array(payload.dig("message", "content"))
      .filter_map { |item| item["text"] if item.is_a?(Hash) && item["type"] == "text" }
      .join("\n")
      .strip

    raise Error, "Cohere returned an empty response." if text.empty?

    text
  rescue JSON::ParserError
    raise Error, "Cohere returned an invalid response."
  rescue Error
    raise
  rescue Timeout::Error, SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET, EOFError => error
    raise Error, "Cohere could not be reached: #{error.message}"
  end

  private

  def default_prompt
    "Analyze the uploaded file(s). Summarize the important information, identify notable details, and explain the result in a clear way."
  end

  def image_attachment?(attachment)
    %w[image/png image/jpeg image/jpg image/webp image/gif].include?(attachment["content_type"].to_s.downcase)
  end

  def image_data_url(attachment)
    path = attachment["storage_path"].to_s
    return nil unless File.file?(path)
    return nil unless attachment["size"].to_i <= 20.megabytes

    bytes = File.binread(path)
    return nil if bytes.empty?

    "data:#{attachment["content_type"]};base64,#{Base64.strict_encode64(bytes)}"
  rescue SystemCallError
    nil
  end

  def request_with_retries(request)
    attempts = 0

    begin
      attempts += 1
      Net::HTTP.start(
        ENDPOINT.hostname,
        ENDPOINT.port,
        use_ssl: true,
        open_timeout: 30,
        read_timeout: 120,
        write_timeout: 60
      ) do |http|
        http.request(request)
      end
    rescue Timeout::Error, SocketError, Errno::ECONNREFUSED, Errno::ECONNRESET, EOFError => error
      retry if attempts < MAX_ATTEMPTS
      raise Error, "Cohere could not be reached after #{attempts} attempts: #{error.message}"
    end
  end

  def error_message(payload, status)
    message = payload.dig("message") || payload.dig("error", "message")
    "Cohere request failed (#{status}): #{message || "unknown error"}"
  end
end
