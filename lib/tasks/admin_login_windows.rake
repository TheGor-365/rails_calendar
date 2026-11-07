namespace :calendar do
  namespace :security do
    desc "Delete expired (older than two days) admin-login rate-limit counters"
    task prune_admin_login_windows: :environment do
      deleted = AdminLoginWindow.prune_expired!
      puts "Expired admin-login counters removed: #{deleted}"
    end
  end
end
