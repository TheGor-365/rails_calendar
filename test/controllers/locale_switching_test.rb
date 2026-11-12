require "test_helper"

class LocaleSwitchingTest < ActionDispatch::IntegrationTest
  LOCALES = {
    "en" => ["Sign in to your workspace", "Choose a service"],
    "ru" => ["Вход в рабочую область", "Выбрать услугу"],
    "hy" => ["Մուտք աշխատանքային տարածք", "Ընտրել ծառայություն"],
    "es" => ["Accede a tu espacio de trabajo", "Elegir servicio"]
  }.freeze

  test "English is the default and locale does not change UTC calendar contract" do
    get sign_in_path
    assert_response :success
    assert_select "html[lang=en]", count: 1
    assert_select "h1", text: LOCALES.fetch("en").first
    assert_equal "UTC", Time.zone.name
  end

  test "changing locale uses a signed cookie and affects account and public content" do
    LOCALES.each do |code, (auth_heading, marketing_cta)|
      post language_path, params: { locale: code, return_to: sign_in_path }
      assert_response :see_other
      assert_redirected_to sign_in_path

      get sign_in_path
      assert_response :success
      assert_select "html[lang=?]", code, count: 1
      assert_select "h1", text: auth_heading
      assert_select "details.rc-locale-switcher", count: 1

      get services_path
      assert_response :success
      assert_select "html[lang=?]", code, count: 1
      assert_select "a.mk-action-primary", text: /#{Regexp.escape(marketing_cta)}/

      get client_registration_privacy_path
      assert_response :success
      assert_select "html[lang=?]", code, count: 1
    end
  end

  test "untrusted locales are rejected with no redirect" do
    post language_path, params: { locale: "xx", return_to: sign_in_path }
    assert_response :unprocessable_entity
    get sign_in_path
    assert_select "html[lang=en]"
  end

  test "redirects never leave the app or accept protocol-relative URLs" do
    %w[https://example.org/private //example.org/private javascript:alert(1)].each do |destination|
      post language_path, params: { locale: "es", return_to: destination }
      assert_response :see_other
      assert_redirected_to services_path
    end
  end

  test "translation keys exist for each shipped module in all four languages" do
    baseline = nil
    %w[en ru hy es].each do |code|
      I18n.with_locale(code) do
        assert_equal code, I18n.locale.to_s
        groups = %w[i18n nav auth flash client mail ai marketing]
        groups.each do |group|
          keys = I18n.t(group, locale: code)
          assert_kind_of Hash, keys
          flat = flatten_keys(keys)
          assert flat.any?, "#{group}:#{code} missing"
          assert_equal baseline.fetch(group), flat if baseline
        end
        baseline ||= groups.to_h { |group| [group, flatten_keys(I18n.t(group, locale: code))] }
      end
    end
  end

  test "localized verification mail keeps the OTP out of HTML and URLs" do
    %w[en ru hy es].each do |code|
      I18n.with_locale(code) do
        message = SignupMailer.verification_code("qa@example.test", "123456")
        assert_includes message.body.decoded, "123456"
        assert_equal I18n.t("mail.subject"), message.subject
      end
    end
  end

  private

  def flatten_keys(value, prefix = "")
    value.flat_map do |key, item|
      if item.is_a?(Hash)
        flatten_keys(item, "#{prefix}#{key}.")
      else
        ["#{prefix}#{key}"]
      end
    end.sort
  end
end
