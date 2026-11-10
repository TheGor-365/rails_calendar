# RC-035: restricted, one-time production owner bootstrap.
# Intentionally not invoked by normal app boot, db:migrate, or db:prepare.
# Must run only as an explicitly selected pre-deploy task after setting private
# RC_OWNER_BOOTSTRAP_EMAIL and RC_OWNER_BOOTSTRAP_PASSWORD in Railway.
# Remove these temporary variables and restore the original pre-deploy command
# after confirming success. Never log the password or expose a public route.

namespace :rc_owner do
  desc "One-time owner bootstrap for production (requires private Railway variables)"
  task bootstrap: :environment do
    abort "RC_OWNER_BOOTSTRAP_WRONG_ENV" unless Rails.env.production?

    email = ENV.fetch("RC_OWNER_BOOTSTRAP_EMAIL", "").strip.downcase
    password = ENV.fetch("RC_OWNER_BOOTSTRAP_PASSWORD", "")

    abort "RC_OWNER_BOOTSTRAP_INVALID_EMAIL" unless URI::MailTo::EMAIL_REGEXP.match?(email)
    abort "RC_OWNER_BOOTSTRAP_INVALID_PASSWORD_LENGTH" unless password.bytesize.between?(16, 72)

    User.transaction do
      # Same application-level lock as RegistrationsController; prevent races.
      User.connection.execute("SELECT pg_advisory_xact_lock(20261108, 32)")
      abort "RC_OWNER_BOOTSTRAP_USERS_ALREADY_EXIST" if User.exists?

      User.create!(
        email: email,
        role: "owner",
        password: password,
        password_confirmation: password
      )
    end

    puts "RC_OWNER_BOOTSTRAP_CREATED"
  end
end
