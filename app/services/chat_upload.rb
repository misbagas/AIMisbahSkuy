require "fileutils"
require "securerandom"

class ChatUpload
  class Error < StandardError; end

  MAX_BYTES = 10.megabytes
  ID_PATTERN = /\A[0-9a-f]{24,64}\z/.freeze

  def self.save(upload)
    new.save(upload)
  end

  def self.path_for(id)
    id = id.to_s
    return nil unless id.match?(ID_PATTERN)

    path = Rails.root.join("storage", "chat_uploads", id)
    path.file? ? path : nil
  end

  def save(upload)
    raise Error, "Choose a file before sending." unless upload.respond_to?(:original_filename)
    raise Error, "That file is too large. The maximum size is 10 MB." if upload.size.to_i > MAX_BYTES

    original_name = File.basename(upload.original_filename.to_s.tr("\\", "/"))
    raise Error, "The uploaded file needs a name." if original_name.empty?

    directory = Rails.root.join("storage", "chat_uploads")
    FileUtils.mkdir_p(directory)

    id = SecureRandom.hex(16)
    stored_path = directory.join(id)

    upload.tempfile.rewind
    File.binwrite(stored_path, upload.tempfile.read)

    {
      "id" => id,
      "name" => original_name,
      "content_type" => upload.content_type.to_s,
      "size" => upload.size.to_i,
      "storage_path" => stored_path.to_s
    }
  rescue SystemCallError => error
    raise Error, "The file could not be saved: #{error.message}"
  end
end
