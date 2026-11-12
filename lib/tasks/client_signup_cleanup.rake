namespace :client_signup do
  desc "Prune expired pending signups and old rate windows; schedule separately after deployment"
  task prune: :environment do
    stale_challenges = ClientSignupChallenge.where("expires_at < ?", 1.day.ago).delete_all
    stale_rates = SignupRateWindow.where("window_start_epoch < ?", 3.days.ago.to_i).delete_all
    puts "Pruned #{stale_challenges} expired challenges and #{stale_rates} stale rate windows"
  end
end
