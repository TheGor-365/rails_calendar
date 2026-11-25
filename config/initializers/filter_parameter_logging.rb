Rails.application.config.filter_parameters += [
  :passw, :secret, :token, :_key, :crypt, :salt, :certificate,
  :otp, :code, :replay_request_token, :outbox_replay_token, :email, :ssn, :reschedule_reason, :goal, :body, :document
]
