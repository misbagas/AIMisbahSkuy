require "open3"
require "shellwords"
require "tmpdir"

class AttachmentReader
  MAX_TEXT_CHARS = 120_000
  TEXT_EXTENSIONS = %w[
    .txt .md .markdown .csv .tsv .json .xml .yaml .yml .log .ini .cfg
    .rb .rs .go .java .kt .kts .js .jsx .ts .tsx .py .php .c .h .cpp .hpp
    .cs .swift .sh .bash .zsh .sql .html .htm .css .scss .sass .vue .svelte
  ].freeze

  def self.read(file)
    new.read(file)
  end

  def read(file)
    return nil unless file.is_a?(Hash)
    return nil if file["storage_path"].blank?

    path = File.expand_path(file["storage_path"].to_s)
    return nil unless File.file?(path)
    return nil unless path.start_with?(Rails.root.join("storage", "chat_uploads").to_s)

    extension = File.extname(file["name"].to_s).downcase
    content_type = file["content_type"].to_s.downcase

    text = if text_file?(extension, content_type)
      File.binread(path).force_encoding("UTF-8").scrub
    elsif content_type == "application/pdf" || extension == ".pdf"
      extract_with_command(["pdftotext", "-layout", path, "-"])
    elsif extension == ".docx"
      extract_with_command(["pandoc", path, "--from=docx", "-t", "plain"])
    elsif extension == ".pptx"
      extract_with_command(["pandoc", path, "--from=pptx", "-t", "plain"])
    elsif extension == ".xlsx" || extension == ".xls"
      extract_spreadsheet(path)
    end

    return nil if text.blank?

    text = text.strip
    text.length > MAX_TEXT_CHARS ? "#{text[0, MAX_TEXT_CHARS]}\n\n[File content truncated at #{MAX_TEXT_CHARS} characters.]" : text
  rescue SystemCallError
    nil
  end

  private

  def text_file?(extension, content_type)
    content_type.start_with?("text/") || TEXT_EXTENSIONS.include?(extension)
  end

  def extract_with_command(command)
    return nil unless executable_available?(command.first)

    stdout, _stderr, status = Open3.capture3(*command)
    status.success? ? stdout : nil
  end

  def executable_available?(command)
    system("command -v #{Shellwords.escape(command)} >/dev/null 2>&1")
  end

  def extract_spreadsheet(path)
    return nil unless executable_available?("libreoffice")

    Dir.mktmpdir("misbah-exploit-ai-sheet") do |dir|
      stdout, stderr, status = Open3.capture3(
        "libreoffice",
        "--headless",
        "--convert-to",
        "csv",
        "--outdir",
        dir,
        path
      )
      return nil unless status.success?

      csv_path = File.join(dir, "#{File.basename(path, ".*")}.csv")
      File.file?(csv_path) ? File.binread(csv_path).force_encoding("UTF-8").scrub : stdout
    end
  rescue Errno::ENOENT
    nil
  end
end
