Rails.application.routes.draw do
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  post "telegram/webhook", to: "telegram#webhook"
  # Legacy path with the bot token in the URL. Remove once TELEGRAM_WEBHOOK_URL
  # points at telegram/webhook in production.
  post "telegram/:token/webhook", to: "telegram#webhook"

  # Defines the root path route ("/")
  # root "posts#index"
end
