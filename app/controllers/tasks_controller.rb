require_relative "../services/cohere_chat"
require_relative "../services/chat_upload"

class TasksController < ApplicationController
  TASK_GREETINGS = [
    "Fire away.",
    "What are we building today?",
    "Name the task.",
    "Drop the prompt.",
    "Let's get to work.",
    "Where should we start?",
    "What's on your mind?",
    "Talk to me.",
    "How can I help you shine today?",
    "Show me what you're working on.",
    "Let's make some magic.",
    "What are we dreaming up today?",
    "Give me a challenge.",
    "Feed me a topic.",
    "Let's brainstorm.",
    "I'm all ears (and algorithms).",
    "Hit me.",
    "Your move.",
    "What's the play?",
    "At your service."
  ].freeze

  before_action :load_sidebar

  def new
    chat_data.delete("chat_messages") if params[:reset].present?
    @prompt = params[:prompt].to_s
    @task_greeting = next_task_greeting

    if params[:recent].present? && @prompt.present?
      @messages = messages_for_recent_prompt(@prompt)
    else
      @messages = chat_data["chat_messages"] || []
    end
  end

  def create
    prompt = params[:prompt].to_s.strip
    attachments = Array(params[:attachments]).reject(&:blank?)
    uploaded_files = []

    if prompt.empty? && attachments.empty?
      redirect_to new_task_path, alert: "Write a prompt or upload a file before sending it."
      return
    end

    @prompt = prompt
    @task_greeting = next_task_greeting

    attachments.each { |attachment| uploaded_files << ChatUpload.save(attachment) }

    @assistant_response = CohereChat.call(
      prompt,
      attachments: uploaded_files
    )

    message_content = prompt.presence || "Analyze the uploaded file(s)"
    user_message = {
      "role" => "user",
      "content" => message_content,
      "attachments" => uploaded_files.map { |file| public_attachment(file) }
    }

    @messages = chat_data["chat_messages"] || []
    @messages << user_message
    @messages << { "role" => "assistant", "content" => @assistant_response }
    chat_data["chat_messages"] = @messages.last(12)

    recent_name = prompt.presence || "Files: #{uploaded_files.map { |file| file["name"] }.join(", ")}"
    remember_recent_prompt(recent_name, @assistant_response)

    @prompt = ""
    render :new
  rescue CohereChat::Error, ChatUpload::Error => error
    @prompt = prompt
    @task_greeting = next_task_greeting
    @messages = chat_data["chat_messages"] || []

    if uploaded_files.any?
      @messages << {
        "role" => "user",
        "content" => prompt.presence || "Analyze the uploaded file(s)",
        "attachments" => uploaded_files.map { |file| public_attachment(file) }
      }
      chat_data["chat_messages"] = @messages.last(12)
    end

    @uploaded_attachments = uploaded_files.map { |file| public_attachment(file) }
    @task_error = error.message
    render :new, status: :unprocessable_entity
  end

  def attachment
    attachment = session_attachments.find { |item| item["id"].to_s == params[:id].to_s }
    path = ChatUpload.path_for(params[:id]) if attachment

    return head :not_found unless path

    content_type = attachment["content_type"].to_s.downcase
    inline_allowed = %w[image/png image/jpeg image/jpg image/webp image/gif video/mp4 video/webm video/ogg].include?(content_type)
    disposition = params[:download].present? || !inline_allowed ? "attachment" : "inline"

    response.headers["X-Content-Type-Options"] = "nosniff"
    send_file path,
      type: attachment["content_type"].presence || "application/octet-stream",
      disposition: disposition,
      filename: attachment["name"].to_s
  end

  def rename_recent
    current_name = params[:current_name].to_s
    new_name = params[:name].to_s.strip

    if current_name.empty? || new_name.empty?
      redirect_to new_task_path, alert: "Enter a name for the recent command."
    else
      recent_projects = Array(chat_data["recent_projects"]).map do |project|
        if recent_project_name(project) == current_name
          { "name" => new_name, "response" => project.is_a?(Hash) ? project["response"] : nil }
        else
          project
        end
      end
      chat_data["recent_projects"] = recent_projects
      redirect_to new_task_path, notice: "Recent command renamed."
    end
  end

  def pin_recent
    current_name = params[:current_name].to_s
    recent_projects = Array(chat_data["recent_projects"])
    pinned_project = recent_projects.find { |project| recent_project_name(project) == current_name }

    if pinned_project
      chat_data["recent_projects"] = recent_projects.reject { |project| recent_project_name(project) == current_name }
      pinned_projects = Array(chat_data["pinned_projects"])
      chat_data["pinned_projects"] = [current_name] + pinned_projects.reject { |project| project == current_name }
      redirect_to new_task_path, notice: "Recent command pinned."
    else
      redirect_to new_task_path, alert: "Recent command could not be found."
    end
  end

  def unpin_project
    project_name = params[:name].to_s
    chat_data["pinned_projects"] = Array(chat_data["pinned_projects"]).reject { |project| project == project_name }
    recent_projects = Array(chat_data["recent_projects"])
    chat_data["recent_projects"] = [
      { "name" => project_name, "response" => nil }
    ] + recent_projects.reject { |project| recent_project_name(project) == project_name }.first(4)
    redirect_to new_task_path, notice: "Project unpinned."
  end

  def archive_project
    project_name = params[:name].to_s
    project = find_project(project_name)

    if project
      remove_project(project_name)
      archived_projects = Array(chat_data["archived_projects"])
      chat_data["archived_projects"] = [project] + archived_projects.reject do |archived_project|
        recent_project_name(archived_project) == project_name
      end.first(9)
      redirect_to new_task_path, notice: "Project archived."
    else
      redirect_to new_task_path, alert: "Project could not be found."
    end
  end

  def unarchive_project
    project_name = params[:name].to_s
    archived_projects = Array(chat_data["archived_projects"])
    project = archived_projects.find { |archived_project| recent_project_name(archived_project) == project_name }

    if project
      chat_data["archived_projects"] = archived_projects.reject do |archived_project|
        recent_project_name(archived_project) == project_name
      end
      recent_projects = Array(chat_data["recent_projects"])
      chat_data["recent_projects"] = [project] + recent_projects.reject do |recent_project|
        recent_project_name(recent_project) == project_name
      end.first(4)
      redirect_to new_task_path, notice: "Project moved back to Recents."
    else
      redirect_to new_task_path, alert: "Archived project could not be found."
    end
  end

  def delete_project
    project_name = params[:name].to_s
    remove_project(project_name)
    chat_data["archived_projects"] = Array(chat_data["archived_projects"]).reject do |project|
      recent_project_name(project) == project_name
    end
    redirect_to new_task_path, notice: "Project deleted."
  end

  def share_project
    project_name = params[:name].to_s
    if find_project(project_name)
      share_link = new_task_url(prompt: project_name, recent: true, reset: true)
      redirect_to new_task_path, notice: "Share link: #{share_link}"
    else
      redirect_to new_task_path, alert: "Project could not be found."
    end
  end

  private

  def public_attachment(file)
    {
      "id" => file["id"],
      "name" => file["name"],
      "content_type" => file["content_type"],
      "size" => file["size"],
      "url" => chat_attachment_path(file["id"]),
      "download_url" => chat_attachment_path(file["id"], download: 1)
    }
  end

  def session_attachments
    Array(chat_data["chat_messages"]).flat_map do |message|
      Array(message["attachments"]).select { |attachment| attachment.is_a?(Hash) }
    end
  end

  def next_task_greeting
    greeting_index = chat_data["task_greeting_index"].to_i
    chat_data["task_greeting_index"] = (greeting_index + 1) % TASK_GREETINGS.length
    TASK_GREETINGS[greeting_index % TASK_GREETINGS.length]
  end

  def messages_for_recent_prompt(prompt)
    recent_project = Array(chat_data["recent_projects"]).find do |project|
      recent_project_name(project) == prompt
    end

    messages = [{ "role" => "user", "content" => prompt }]
    response = recent_project.is_a?(Hash) ? recent_project["response"] : nil
    messages << { "role" => "assistant", "content" => response } if response.present?
    messages
  end

  def recent_project_name(project)
    project.is_a?(Hash) ? project["name"].to_s : project.to_s
  end

  def find_project(project_name)
    (Array(chat_data["recent_projects"]) + Array(chat_data["pinned_projects"]) + Array(chat_data["archived_projects"]))
      .find { |project| recent_project_name(project) == project_name }
  end

  def remove_project(project_name)
    chat_data["recent_projects"] = Array(chat_data["recent_projects"]).reject do |project|
      recent_project_name(project) == project_name
    end
    chat_data["pinned_projects"] = Array(chat_data["pinned_projects"]).reject do |project|
      recent_project_name(project) == project_name
    end
  end

  def remember_recent_prompt(prompt, response)
    recent_projects = chat_data["recent_projects"] || []
    recent_projects = recent_projects.reject { |project| recent_project_name(project) == prompt }
    chat_data["recent_projects"] = [{ "name" => prompt, "response" => response }] + recent_projects.first(4)
    @recent_projects = chat_data["recent_projects"]
  end

  def load_sidebar
    @saved_projects = [
    ] + Array(chat_data["pinned_projects"])

    @credits = 2400
    @recent_projects = chat_data["recent_projects"] || []
    @archived_projects = chat_data["archived_projects"] || []
  end
end
