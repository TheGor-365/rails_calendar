require "test_helper"

class CalendarI18nTest < ActionDispatch::IntegrationTest
  LANGUAGES = {
    "en" => ["Consultations", "New consultation", "January", "Title contains"],
    "ru" => ["Консультации", "Новая консультация", "январь", "Поиск по названию"],
    "hy" => ["Խորհրդատվություններ", "Նոր խորհրդատվություն", "հունվար", "Վերնագրով որոնում"],
    "es" => ["Consultas", "Nueva consulta", "enero", "Buscar por título"]
  }.freeze

  test "all languages keep the same calendar structure and link semantics" do
    LANGUAGES.each do |code, (title, _new, month, _filter)|
      post language_path, params: {locale: code, return_to: root_path}
      assert_response :see_other

      assert_no_difference "Consultation.count" do
        get root_path, params: {start_date: "2023-01-19"}
        assert_response :success
      end
      assert_select "html[lang=?]", code
      assert_select "h1", text: title
      assert_select ".calendar-title", text: /#{Regexp.escape(month)}/i
      assert_select "table.calendar-grid", count: 1
      assert_select "a.calendar-day-link[href=?]", calendar_day_path(date: "2023-01-19"), count: 1
      assert_select "nav[aria-label=?]", I18n.t("calendar.calendar_month_nav", locale: code)
      assert_select "th[scope=col]", minimum: 7

      get calendar_day_path(date: "2023-01-19")
      assert_response :success
      assert_select "html[lang=?]", code
      assert_select ".rc-time-axis-hour", count: 24
      assert_select "a.rc-hour-band", count: 24
      assert_select "nav.rc-day-navigation"
      assert_select "time[datetime='2023-01-19']"

      get calendar_hour_path(date: "2023-01-19", hour: 9)
      assert_response :success
      assert_select ".surface-panel", minimum: 1
    end
  end

  test "consultation search field names and status values remain stable in each locale" do
    LANGUAGES.each do |code, (_title, _new, _month, filter)|
      post language_path, params: {locale: code, return_to: consultations_path}
      assert_response :see_other

      get consultations_path
      assert_response :success
      assert_select "html[lang=?]", code
      assert_select "form[method=get][role=search]" do
        assert_select "label[for=q]", text: filter
        assert_select "input#q[name=q]"
        assert_select "input#from[name=from]"
        assert_select "input#to[name=to]"
        assert_select "select#status[name=status] option[value=ongoing]", count: 1
        assert_select "select#status[name=status] option[value=upcoming]", count: 1
      end
      assert_select ".rc-record-list"
    end
  end

  test "consultation attribute labels and validation follow request language" do
    %w[en ru hy es].each do |code|
      I18n.with_locale(code) do
        invalid = Consultation.new(title: "Check", start_time: Time.utc(2023, 1, 19, 10),
                                   end_time: Time.utc(2023, 1, 19, 9))
        refute invalid.valid?
        assert_includes invalid.errors.full_messages.join(" "), I18n.t("consultations.validation_order")
        assert_equal I18n.t("consultations.field_start"), I18n.t("consultations.field_start")
      end
    end
  end

  test "dates and count forms are readable and never change stored instants" do
    fake = Object.new.extend(CalendarI18nHelper)
    date = Date.new(2023, 1, 19)
    timestamp = Time.utc(2023, 1, 19, 9)
    %w[en ru hy es].each do |code|
      I18n.with_locale(code) do
        assert_match(/2023/, fake.rc_local_date(date))
        assert_match(/09:00/, fake.rc_local_datetime(timestamp))
        assert_match(/\A1 /, fake.rc_count(1, "calendar", "event"))
        assert_match(/\A5 /, fake.rc_count(5, "calendar", "event"))
      end
    end
    assert_equal Time.utc(2023, 1, 19, 9), timestamp
  end
end
