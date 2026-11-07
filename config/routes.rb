Rails.application.routes.draw do
  root "pages#home"
  get "calendar/day", to: "pages#day", as: :calendar_day
  get "calendar/hour", to: "pages#hour", as: :calendar_hour

  namespace :admin do
    get "login", to: "sessions#new", as: :login
    post "login", to: "sessions#create", as: :session
    delete "logout", to: "sessions#destroy", as: :logout
  end

  resources :consultations

  # Public intake is disabled unless an explicitly synthetic demo is enabled.
  resources :project_intakes, only: %i[new create show] do
    member do
      post :reply
      post :acknowledge
    end
  end

  namespace :admin do
    resources :project_intakes, only: [:index] do
      member do
        post :draft_spec
        post :approve_spec
      end
    end
  end
end
