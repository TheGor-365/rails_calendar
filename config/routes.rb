Rails.application.routes.draw do
  post "/language", to: "locales#update", as: :language
  # RC-032: local owner bootstrap and DB-backed account sessions.
  get "/sign_up", to: "registrations#new", as: :sign_up
  post "/sign_up", to: "registrations#create"
  get "/sign_in", to: "account_sessions#new", as: :sign_in
  post "/sign_in", to: "account_sessions#create", as: :account_session
  delete "/sign_out", to: "account_sessions#destroy", as: :sign_out

  # RC-034: owner-only synthetic quiz; legacy intake interview stays intact.
  get "/project_intakes/:project_intake_id/quiz", to: "intake_quizzes#show", as: :project_intake_quiz
  get "/project_intakes/:project_intake_id/quiz/review", to: "intake_quizzes#review", as: :review_project_intake_quiz
  patch "/project_intakes/:project_intake_id/quiz/:question_key", to: "intake_quizzes#update", as: :project_intake_quiz_answer

  # Verification-gated client account creation. No private owner grants.
  get "/register", to: "client_registrations#new", as: :client_registration
  post "/register", to: "client_registrations#create"
  get "/register/verify", to: "client_registrations#verify_form", as: :verify_client_registration
  post "/register/verify", to: "client_registrations#verify"
  post "/register/resend", to: "client_registrations#resend", as: :resend_client_registration
  get "/register/privacy", to: "client_registrations#privacy", as: :client_registration_privacy
  get "/client", to: "client_home#show", as: :client_home
  get "/client/cabinet", to: "client_home#show", as: :client_cabinet
  # Verified-client, local-only, fictional request handoff pilot.
  get "/client/requests/new", to: "client_requests#new", as: :new_client_request
  post "/client/requests", to: "client_requests#create", as: :client_requests
  get "/client/requests/:id", to: "client_requests#show", as: :client_request
  post "/client/requests/:id/reply", to: "client_requests#reply", as: :reply_client_request
  post "/client/requests/:id/review", to: "client_requests#review", as: :review_client_request

  # Private owner entry, never a public client cabinet.
  get "/workspace", to: "workspace#home", as: :workspace

  # RC052: owner-only professional intelligence, AI review and immutable approval.
  get "/workspace/setup", to: "owner_setup#show", as: :owner_setup
  patch "/workspace/setup/sections/:section_key", to: "owner_setup#update", as: :owner_setup_section
  get "/workspace/setup/review", to: "owner_setup#review", as: :owner_setup_review
  post "/workspace/setup/suggest", to: "owner_setup#suggest", as: :owner_setup_suggest
  post "/workspace/setup/approve", to: "owner_setup#approve", as: :owner_setup_approve
  get "/workspace/practice", to: "owner_setup#practice", as: :owner_practice

  # RC055.1: private owner-controlled service offering revisions.
  get "/workspace/services", to: "owner_service_offerings#index", as: :owner_services
  post "/workspace/services/sync", to: "owner_service_offerings#sync", as: :sync_owner_services
  post "/workspace/services/approve_all", to: "owner_service_offerings#approve_all", as: :approve_all_owner_services
  get "/workspace/services/new", to: "owner_service_offerings#new", as: :new_owner_service
  post "/workspace/services", to: "owner_service_offerings#create"
  get "/workspace/services/:id", to: "owner_service_offerings#show", as: :owner_service
  patch "/workspace/services/:id/draft", to: "owner_service_offerings#update_draft", as: :owner_service_draft
  post "/workspace/services/:id/approve", to: "owner_service_offerings#approve", as: :approve_owner_service
  post "/workspace/services/:id/publish", to: "owner_service_offerings#publish", as: :publish_owner_service
  post "/workspace/services/:id/unpublish", to: "owner_service_offerings#unpublish", as: :unpublish_owner_service
  post "/workspace/services/:id/new_revision", to: "owner_service_offerings#new_revision", as: :revise_owner_service
  get "/workspace/practice/capabilities", to: "owner_capabilities#index", as: :owner_capabilities
  patch "/workspace/practice/capabilities/:capability_key", to: "owner_capabilities#update", as: :owner_capability
  delete "/workspace/practice/capabilities/:capability_key", to: "owner_capabilities#discard", as: :discard_owner_capability
  post "/workspace/practice/capabilities/suggest", to: "owner_capabilities#suggest", as: :suggest_owner_capabilities
  post "/workspace/practice/capabilities/approve", to: "owner_capabilities#approve", as: :approve_owner_capabilities
  get "/workspace/cabinet", to: "owner_setup#cabinet", as: :owner_cabinet
  get "/workspace/ai", to: "owner_setup#ai_activity", as: :owner_ai_activity

  # Public commercial showcase; never accepts or stores visitor contact data.
  get "/services", to: "marketing#index", as: :services
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
        get :edit_spec
        patch :revise_spec
        post :approve_spec
        post :plan
      end
    end
  end
end
