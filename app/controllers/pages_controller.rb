class PagesController < ApplicationController
  before_action :load_sidebar

  def home
  end

  def services
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
