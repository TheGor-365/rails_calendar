Rails.application.config.filter_parameters += [
  :passw, :secret, :token, :_key, :crypt, :salt, :certificate,
  :otp, :code, :email, :ssn, :reschedule_reason, :goal, :body, :document
]
