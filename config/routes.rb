Rails.application.routes.draw do
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

  # RC-035B: separate owner-only adaptive workflow; legacy two-card quiz unchanged.
  get "/project_intakes/:project_intake_id/quiz/adaptive",
      to: "adaptive_intake_quizzes#show", as: :adaptive_project_intake_quiz
  get "/project_intakes/:project_intake_id/quiz/adaptive/review",
      to: "adaptive_intake_quizzes#review", as: :review_adaptive_project_intake_quiz
  patch "/project_intakes/:project_intake_id/quiz/adaptive/:question_key",
        to: "adaptive_intake_quizzes#update", as: :adaptive_project_intake_quiz_answer

  # RC-037: explicit owner-only offline preference controls (nonproduction).
  get "/workspaces/:workspace_id/project_intakes/:id/ai_settings",
      to: "studio/ai_settings#show", as: :workspace_ai_settings
  patch "/workspaces/:workspace_id/project_intakes/:id/ai_settings",
        to: "studio/ai_settings#update"

  # RC-037: explicit deterministic offline proposal, never provider execution.
  post "/workspaces/:workspace_id/project_intakes/:id/offline_proposal",
       to: "studio/ai_settings#preview", as: :workspace_offline_proposal

  # RC-037 Slice H: explicit signed synthetic run + one owner review; nonproduction.
  post "/workspaces/:workspace_id/project_intakes/:id/offline_runs",
       to: "studio/ai_settings#record_run", as: :workspace_offline_runs
  post "/workspaces/:workspace_id/project_intakes/:id/offline_runs/:run_id/review",
       to: "studio/ai_settings#review_run", as: :workspace_offline_run_review

  # Owner-only Studio preview. No client access, persistence or AI calls.
  get "/workspaces/:workspace_id/project_intakes/:id/source_preview",
      to: "studio/source_previews#new", as: :workspace_source_preview
  post "/workspaces/:workspace_id/project_intakes/:id/source_preview",
       to: "studio/source_previews#create"

  # RC-036 Stage 3 Slice F: invitation-bound client identity in test/local only.
  # No public sign-up, no files, and all client routes deny production.
  post "/studio/client_accounts", to: "studio/client_accounts#create", as: :studio_client_accounts
  post "/studio/client_sessions", to: "studio/client_sessions#create", as: :studio_client_sessions
  delete "/studio/client_sessions", to: "studio/client_sessions#destroy"
  get "/studio/client_projects", to: "studio/client_projects#index", as: :studio_client_projects
  post "/studio/client_projects/accept", to: "studio/client_projects#accept", as: :accept_studio_client_project
  get "/studio/client_projects/:id", to: "studio/client_projects#show", as: :studio_client_project

  # RC-036 Stage 3 Slice E: synthetic, nonproduction-only email possession proof.
  # No account creation, client login, invitation acceptance or data access.
  post "/studio/invitations/email_proofs",
       to: "studio/invitation_email_proofs#create", as: :studio_invitation_email_proofs
  post "/studio/invitations/email_proofs/confirm",
       to: "studio/invitation_email_proofs#confirm", as: :confirm_studio_invitation_email_proof

  # RC-036 Stage 3 Slice B: owner-only metadata and pending invitations.
  scope "/workspaces/:workspace_id/clients/:client_id/project_intakes/:project_intake_id" do
    get "/sources", to: "studio/project_sources#index", as: :studio_project_sources
    post "/sources", to: "studio/project_sources#create"
    post "/sources/:id/scan", to: "studio/project_sources#scan", as: :studio_project_source_scan
    post "/sources/:id/queue_scan", to: "studio/project_sources#queue_scan",
         as: :studio_project_source_queue_scan
    get "/sources/:id/download", to: "studio/project_sources#download", as: :studio_project_source_download
    get "/invitations", to: "studio/project_invitations#index", as: :studio_project_invitations
    post "/invitations", to: "studio/project_invitations#create"
    delete "/invitations/:id", to: "studio/project_invitations#destroy", as: :studio_project_invitation
  end


  # RC-039 Slice C: fictional metadata HTTP contract is registered ONLY in
  # Rails test mode. Never expose card writes via development or production.
  if Rails.env.test?
    scope "/workspaces/:workspace_id/clients/:client_id/project_intakes/:project_intake_id" do
      get "/project_hub", to: "studio/synthetic_project_cards#index",
          as: :rc039_synthetic_project_hub
      post "/project_hub/cards", to: "studio/synthetic_project_cards#create",
           as: :rc039_synthetic_project_cards
      patch "/project_hub/cards/:card_id", to: "studio/synthetic_project_cards#update",
            as: :rc039_synthetic_project_card
      # RC-039 Slice D: HTML UI available ONLY under the test-only parent scope.
      get "/project_hub/preview", to: "studio/synthetic_project_cards#show_preview",
          as: :rc039_synthetic_project_hub_preview
      post "/project_hub/preview/cards", to: "studio/synthetic_project_cards#create_preview_card",
           as: :rc039_synthetic_project_hub_preview_cards
      patch "/project_hub/preview/cards/:card_id",
            to: "studio/synthetic_project_cards#transition_preview_card",
            as: :rc039_synthetic_project_hub_preview_card
    end
  end

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
