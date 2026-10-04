require "test_helper"

class TasksControllerTest < ActionDispatch::IntegrationTest
  test "should get new task workspace" do
    get new_task_url
    assert_response :success
    assert_includes response.body, "name=\"attachments[]\""
  end

  test "should accept a task prompt" do
    original_call = CohereChat.method(:call)
    CohereChat.define_singleton_method(:call) { |_prompt, attachments: []| "Here is a launch brief." }

    begin
      post tasks_url, params: { prompt: "Plan a launch brief" }
    ensure
      CohereChat.define_singleton_method(:call, original_call)
    end

    assert_response :success
    assert_includes response.body, "Here is a launch brief."
  end

  test "should upload a file and show it in the chat" do
    original_call = CohereChat.method(:call)
    CohereChat.define_singleton_method(:call) do |prompt, attachments: []|
      file = attachments.first
      context = AttachmentReader.read(file)
      raise "missing file context" unless file["name"] == "chat_context.txt" && context.include?("scheduled for Friday")

      "The launch is scheduled for Friday."
    end

    begin
      upload = fixture_file_upload("chat_context.txt", "text/plain")
      post tasks_url, params: { prompt: "Summarize this file", attachments: [upload] }
    ensure
      CohereChat.define_singleton_method(:call, original_call)
    end

    assert_response :success
    assert_includes response.body, "chat_context.txt"
    assert_includes response.body, "The launch is scheduled for Friday."
  end

  test "should serve an uploaded attachment to the current chat" do
    original_call = CohereChat.method(:call)
    CohereChat.define_singleton_method(:call) { |_prompt, attachments: []| "Attachment received." }

    begin
      upload = fixture_file_upload("chat_context.txt", "text/plain")
      post tasks_url, params: { prompt: "Read this", attachments: [upload] }
      attachment_id = response.body[/\/attachments\/([0-9a-f]+)/, 1]
      get chat_attachment_url(attachment_id)
    ensure
      CohereChat.define_singleton_method(:call, original_call)
    end

    assert_response :success
    assert_includes response.body, "scheduled for Friday"
  end

  test "should reopen a recent command with its response" do
    original_call = CohereChat.method(:call)
    CohereChat.define_singleton_method(:call) { |_prompt, attachments: []| "Saved assistant response." }

    begin
      post tasks_url, params: { prompt: "Plan a launch brief" }
      get new_task_url(prompt: "Plan a launch brief", recent: true, reset: true)
    ensure
      CohereChat.define_singleton_method(:call, original_call)
    end

    assert_response :success
    assert_includes response.body, "Plan a launch brief"
    assert_includes response.body, "Saved assistant response."
    assert_includes response.body, "Rename"
    assert_includes response.body, "Archive"
    assert_includes response.body, "Delete"
    assert_includes response.body, "Share"
    assert_includes response.body, "Pin"
  end

  test "should rename a recent command" do
    original_call = CohereChat.method(:call)
    CohereChat.define_singleton_method(:call) { |_prompt, attachments: []| "Saved assistant response." }

    begin
      post tasks_url, params: { prompt: "Plan a launch brief" }
      patch rename_recent_url, params: {
        current_name: "Plan a launch brief",
        name: "Launch brief"
      }
      get new_task_url
    ensure
      CohereChat.define_singleton_method(:call, original_call)
    end

    assert_response :success
    assert_includes response.body, "Launch brief"
  end

  test "should pin a recent command" do
    original_call = CohereChat.method(:call)
    CohereChat.define_singleton_method(:call) { |_prompt, attachments: []| "Saved assistant response." }

    begin
      post tasks_url, params: { prompt: "Important task" }
      patch pin_recent_url, params: { current_name: "Important task" }
      get root_url
    ensure
      CohereChat.define_singleton_method(:call, original_call)
    end

    assert_response :success
    assert_includes response.body, "PINNED"
    assert_includes response.body, "Important task"
  end

  test "should unpin a pinned command" do
    original_call = CohereChat.method(:call)
    CohereChat.define_singleton_method(:call) { |_prompt, attachments: []| "Saved assistant response." }

    begin
      post tasks_url, params: { prompt: "Temporary pinned task" }
      patch pin_recent_url, params: { current_name: "Temporary pinned task" }
      patch unpin_project_url, params: { name: "Temporary pinned task" }
    ensure
      CohereChat.define_singleton_method(:call, original_call)
    end

    get root_url

    assert_response :success
    assert_includes response.body, "PINNED"
    assert_includes response.body, "RECENTS"
    assert_includes response.body, "Temporary pinned task"
  end

  test "should archive a recent command" do
    original_call = CohereChat.method(:call)
    CohereChat.define_singleton_method(:call) { |_prompt, attachments: []| "Saved assistant response." }

    begin
      post tasks_url, params: { prompt: "Archive this task" }
      patch archive_project_url, params: { name: "Archive this task" }
      get root_url
    ensure
      CohereChat.define_singleton_method(:call, original_call)
    end

    assert_response :success
    assert_includes response.body, "ARCHIVED"
    assert_includes response.body, "Archive this task"
  end

  test "should delete a project" do
    original_call = CohereChat.method(:call)
    CohereChat.define_singleton_method(:call) { |_prompt, attachments: []| "Saved assistant response." }

    begin
      post tasks_url, params: { prompt: "Delete this task" }
      delete delete_project_url, params: { name: "Delete this task" }
      get root_url
    ensure
      CohereChat.define_singleton_method(:call, original_call)
    end

    assert_response :success
    refute_includes response.body, "Delete this task"
  end

  test "should unarchive a project into recents" do
    original_call = CohereChat.method(:call)
    CohereChat.define_singleton_method(:call) { |_prompt, attachments: []| "Saved assistant response." }

    begin
      post tasks_url, params: { prompt: "Restore this task" }
      patch archive_project_url, params: { name: "Restore this task" }
      patch unarchive_project_url, params: { name: "Restore this task" }
      get root_url
    ensure
      CohereChat.define_singleton_method(:call, original_call)
    end

    assert_response :success
    assert_includes response.body, "RECENTS"
    assert_includes response.body, "Restore this task"
  end
end
