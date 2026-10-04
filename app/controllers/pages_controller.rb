class PagesController < ApplicationController
  before_action :load_sidebar
  skip_forgery_protection only: :resume_maker_script

  def home
  end

  def services
  end

  def resume_maker
    render file: Rails.root.join("..", "index.html"), layout: false, content_type: "text/html"
  end

  def resume_maker_stylesheet
    send_file Rails.root.join("..", "styles.css"), type: "text/css", disposition: "inline"
  end

  def resume_maker_script
    send_file Rails.root.join("..", "app.js"), type: "text/javascript", disposition: "inline"
  end

  def automations
  end

  private

  def load_sidebar
    @saved_projects = [
    ] + Array(chat_data["pinned_projects"])

    @credits = 2400
    @recent_projects = chat_data["recent_projects"] || []
    @archived_projects = chat_data["archived_projects"] || []
  end
end
