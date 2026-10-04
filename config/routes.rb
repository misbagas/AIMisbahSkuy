Rails.application.routes.draw do
  root "pages#home"
  get "/homebase", to: "pages#home", as: :homebase

  get "/tasks/new", to: "tasks#new", as: :new_task
  post "/tasks", to: "tasks#create", as: :tasks
  get "/attachments/:id", to: "tasks#attachment", as: :chat_attachment
  patch "/recent-projects", to: "tasks#rename_recent", as: :rename_recent
  patch "/recent-projects/pin", to: "tasks#pin_recent", as: :pin_recent
  patch "/pinned-projects/unpin", to: "tasks#unpin_project", as: :unpin_project
  patch "/projects/archive", to: "tasks#archive_project", as: :archive_project
  patch "/projects/unarchive", to: "tasks#unarchive_project", as: :unarchive_project
  delete "/projects", to: "tasks#delete_project", as: :delete_project
  post "/projects/share", to: "tasks#share_project", as: :share_project
  get "/services", to: "pages#services", as: :services
  get "/resume-maker", to: "pages#resume_maker", as: :resume_maker
  get "/styles.css", to: "pages#resume_maker_stylesheet", as: :resume_maker_stylesheet
  get "/app.js", to: "pages#resume_maker_script", as: :resume_maker_script
  get "/automations", to: "pages#automations", as: :automations

  get "up" => "rails/health#show", as: :rails_health_check
end
