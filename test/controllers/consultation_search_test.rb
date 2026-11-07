require "test_helper"

class ConsultationSearchTest < ActionDispatch::IntegrationTest
  setup do
    @one = consultations(:one)
    @two = consultations(:two)
  end

  test "index preserves existing list and has a labeled responsive search form" do
    get consultations_url
    assert_response :success

    assert_select "form[role='search'][aria-label='Filter consultations'][method='get']" do
      assert_select "input#q[type='search']", count: 1
      assert_select "input#from[type='date']", count: 1
      assert_select "input#to[type='date']", count: 1
      assert_select "select#status", count: 1
      assert_select "button[type='submit']", text: /Apply filters/
    end

    assert_select "li.rc-record", count: 2
    assert_select "a[href=?]", consultation_path(@one), minimum: 1
    assert_select "a[href=?]", consultation_path(@two), minimum: 1
  end

  test "case-insensitive title matching is safely escaped for percent and underscore" do
    starts = Time.zone.local(2026, 11, 13, 11)
    percent = Consultation.create!(title: "100% Ruby_Rails", start_time: starts, end_time: starts + 30.minutes)
    Consultation.create!(title: "100 percent RubyXRails", start_time: starts + 1.hour, end_time: starts + 90.minutes)

    get consultations_url(q: "100% Ruby_")
    assert_response :success
    assert_select "li.rc-record", count: 1
    assert_select "li#consultation_#{percent.id}", count: 1

    get consultations_url(q: "MYSTRING")
    assert_response :success
    assert_select "li#consultation_#{@one.id}", count: 1
    assert_select "li#consultation_#{@two.id}", count: 0
  end

  test "UTC date filters use half-open overlap including events spanning midnight" do
    spanning = Consultation.create!(
      title: "Spans two UTC dates",
      start_time: Time.zone.local(2026, 11, 12, 23, 30),
      end_time: Time.zone.local(2026, 11, 13, 1, 30)
    )
    ending_at_midnight = Consultation.create!(
      title: "Ends at midnight UTC",
      start_time: Time.zone.local(2026, 11, 12, 23),
      end_time: Time.zone.local(2026, 11, 13, 0)
    )
    starts_next = Consultation.create!(
      title: "Starts at midnight UTC",
      start_time: Time.zone.local(2026, 11, 13, 0),
      end_time: Time.zone.local(2026, 11, 13, 0, 30)
    )

    get consultations_url(from: "2026-11-13", to: "2026-11-13")
    assert_response :success
    assert_select "li#consultation_#{spanning.id}", count: 1
    assert_select "li#consultation_#{starts_next.id}", count: 1
    assert_select "li#consultation_#{ending_at_midnight.id}", count: 0

    get consultations_url(from: "2026-11-12", to: "2026-11-12")
    assert_response :success
    assert_select "li#consultation_#{ending_at_midnight.id}", count: 1
    assert_select "li#consultation_#{starts_next.id}", count: 0
  end

  test "upcoming ongoing and past filters use disjoint boundaries" do
    travel_to Time.zone.local(2026, 11, 7, 12) do
      current = Consultation.create!(
        title: "Current item", start_time: Time.zone.local(2026, 11, 7, 11),
        end_time: Time.zone.local(2026, 11, 7, 13)
      )
      future = Consultation.create!(
        title: "Future item", start_time: Time.zone.local(2026, 11, 8, 9),
        end_time: Time.zone.local(2026, 11, 8, 10)
      )

      get consultations_url(status: "upcoming")
      assert_select "li#consultation_#{future.id}", count: 1
      assert_select "li#consultation_#{current.id}", count: 0

      get consultations_url(status: "ongoing")
      assert_select "li#consultation_#{current.id}", count: 1
      assert_select "li#consultation_#{future.id}", count: 0

      get consultations_url(status: "past")
      assert_select "li#consultation_#{@one.id}", count: 1
      assert_select "li#consultation_#{future.id}", count: 0
    end
  end

  test "invalid filters render actionable errors, not an unfiltered data disclosure" do
    [
      { from: "2026-02-30" },
      { to: "2026-13-01" },
      { from: "2026-11-14", to: "2026-11-13" },
      { status: "nonexistent" },
      { q: "a" * 121 },
      { from: "1999-12-31" }
    ].each do |query|
      get consultations_url(query)
      assert_response :success
      assert_select "#consultation-filter-errors[role='alert']", count: 1
      assert_select "li.rc-record", count: 0
    end
  end

  test "no matches have a usable empty state and Clear action" do
    get consultations_url(q: "No such consultation")
    assert_response :success
    assert_select "li.rc-record", count: 0
    assert_select ".rc-notice--neutral", text: /No results for these filters/
    assert_select "a[href=?]", consultations_path, text: /Clear/
  end

  test "pagination is deterministic and retains search filters" do
    start = Time.zone.local(2026, 11, 13, 9)
    25.times do |i|
      Consultation.create!(
        title: "Paged item #{i.to_s.rjust(2, '0')}",
        start_time: start + i.hours,
        end_time: start + i.hours + 30.minutes
      )
    end

    get consultations_url(q: "Paged item", page: "1")
    assert_response :success
    assert_select "li.rc-record", count: 20
    assert_select ".rc-results-summary", text: /Showing 1–20 of 25 consultations/
    assert_select "nav[aria-label='Consultation result pages'] a[rel='next']", count: 1
    assert_select "nav[aria-label='Consultation result pages'] a[rel='next'][href*='q=Paged']", count: 1

    get consultations_url(q: "Paged item", page: "2")
    assert_response :success
    assert_select "li.rc-record", count: 5
    assert_select ".rc-results-summary", text: /Showing 21–25 of 25 consultations/
    assert_select "nav[aria-label='Consultation result pages'] a[rel='prev']", count: 1

    # Oversized and malformed pagination cannot create giant offsets/500s.
    get consultations_url(q: "Paged item", page: "999999")
    assert_response :success
    assert_select "li.rc-record", count: 5
    get consultations_url(q: "Paged item", page: "-17")
    assert_response :success
    assert_select "li.rc-record", count: 20
  end

  test "private mode still denies unauthenticated filtered index" do
    original = ENV["RAILS_CALENDAR_PUBLIC_DEMO_MODE"]
    ENV["RAILS_CALENDAR_PUBLIC_DEMO_MODE"] = "false"

    get consultations_url(q: @one.title, from: "2023-01-19", status: "past")
    assert_redirected_to admin_login_url
  ensure
    if original.nil?
      ENV.delete("RAILS_CALENDAR_PUBLIC_DEMO_MODE")
    else
      ENV["RAILS_CALENDAR_PUBLIC_DEMO_MODE"] = original
    end
  end
end
