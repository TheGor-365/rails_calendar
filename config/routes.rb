Rails.application.routes.draw do
  root "pages#home"
  get "calendar/day", to: "pages#day", as: :calendar_day

  namespace :admin do
    get "login", to: "sessions#new", as: :login
    post "login", to: "sessions#create", as: :session
    delete "logout", to: "sessions#destroy", as: :logout
  end

  resources :consultations
end
