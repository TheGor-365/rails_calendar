# CSRF-protected POST language preference; never mutates authorization or account.
class LocalesController < ApplicationController
  def update
    selected = params[:locale].to_s
    return head :unprocessable_entity unless %w[en ru hy es].include?(selected)

    cookies.signed[:rc_locale] = {
      value: selected, expires: 1.year.from_now, same_site: :lax,
      httponly: true, secure: Rails.env.production?
    }

    destination = params[:return_to].to_s
    path = begin
      uri = URI.parse(destination)
      uri.path.to_s.start_with?("/") && !destination.start_with?("//") &&
        uri.scheme.nil? && uri.host.nil? && !destination.match?(/[\r\n]/) &&
        destination.bytesize <= 2048 && uri.path != language_path ? destination : services_path
    rescue URI::InvalidURIError
      services_path
    end
    redirect_to path, allow_other_host: false, status: :see_other
  end
end
