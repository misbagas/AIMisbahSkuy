# MisbahExploitAI

MisbahExploitAI is a Rails 8 chat workspace backed by Cohere. The chat composer supports prompts and file attachments in the same message. Uploaded files are stored on the server, rendered back under the user message, and their usable content is passed to Cohere for analysis.

## File upload flow

1. The browser selects or drops one or more files.
2. Rails receives the multipart form and stores each file in `storage/chat_uploads`.
3. The chat message stores safe attachment metadata plus an internal attachment ID in the session.
4. `/attachments/:id` serves the file only when that attachment belongs to the current chat session.
5. Text-like files are extracted into Cohere `documents`, images are sent as Cohere image inputs, and PDF/DOCX/PPTX/XLSX extraction is attempted through server-side converters when available.
6. Cohere returns the analysis, which is rendered as the assistant message directly below the uploaded file.

## Supported analysis paths

Text/code/JSON/CSV/Markdown and similar text files are read directly. PDF uses `pdftotext`; DOC/DOCX/PPTX uses `pandoc`; spreadsheets can use LibreOffice when it is installed. Images are sent to a Cohere vision-capable model. Video and other binary files are stored and rendered in the chat, but are not treated as directly readable AI documents.

The upload limit is 10 MB per file. Extracted text is capped per file and across the request to keep chat requests bounded.

## Configuration

Set these environment variables before using AI:

```bash
COHERE_API_KEY=your_api_key
COHERE_MODEL=command-a-03-2025
COHERE_VISION_MODEL=command-a-vision-07-2025
COHERE_MAX_OUTPUT_TOKENS=2000
```

`COHERE_MODEL` is used for normal text requests. Image messages use `COHERE_VISION_MODEL` when it is set.

## Local setup

```bash
bin/rails db:prepare
bin/dev
```

Or run the Rails server directly:

```bash
bin/rails server
```

The app is normally available at `http://localhost:3000`.

## Production/Docker

The production image installs `poppler-utils` and `pandoc` so PDF and document extraction can work in the container. Uploaded files remain in `storage/chat_uploads`, so production deployments should use a persistent volume or move attachment storage to object storage when multiple application instances are used.
