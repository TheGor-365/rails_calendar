class ApplicationController < ActionController::Base
  include AccountAuthentication
  include AdminAuthentication

  around_action :use_ui_locale

  private

  def use_ui_locale(&block)
    selected = cookies.signed[:rc_locale].to_s
    selected = "en" unless %w[en ru hy es].include?(selected)
    I18n.with_locale(selected, &block)
  end

end
