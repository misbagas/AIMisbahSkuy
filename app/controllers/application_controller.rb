class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  before_action :load_chat_state
  after_action :persist_chat_state

  private

  def load_chat_state
    @chat_state = if session[:chat_state_key].present?
      ChatSession.find_by(key: session[:chat_state_key])
    end

    unless @chat_state
      @chat_state = ChatSession.create!(key: SecureRandom.hex(16), data: {})
      session[:chat_state_key] = @chat_state.key
    end

    @chat_data = @chat_state.data
    %i[chat_messages recent_projects pinned_projects archived_projects task_greeting_index].each do |legacy_key|
      @chat_data[legacy_key.to_s] = session.delete(legacy_key) if session.key?(legacy_key)
    end
  end

  def chat_data
    @chat_data
  end

  def persist_chat_state
    return unless @chat_state

    @chat_state.update!(data: @chat_data)
  end
end
