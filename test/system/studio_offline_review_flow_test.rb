require "application_system_test_case"

# RC-037 acceptance: real Chrome UI, synthetic owner only, no provider calls.
# This is CI Chrome evidence, NOT a substitute for the owner's Linux Mint run.
class StudioOfflineReviewFlowTest < ApplicationSystemTestCase
  setup do
    suffix = SecureRandom.hex(5)
    @password = "synthetic-studio-mobile-acceptance-password"
    @owner = User.create!(email: "studio-mobile-owner-#{suffix}@example.test",
      role: "owner", password: @password, password_confirmation: @password)
    @workspace = Workspace.create!(
      owner_user: @owner, name: "Studio narrow-screen synthetic",
      slug: "studio-mobile-#{suffix}"
    )
    WorkspaceMembership.create!(
      workspace: @workspace, user: @owner, role: "owner", status: "active"
    )
    client = @workspace.clients.create!(display_name: "Entirely fictional owner UI")
    @intake = @workspace.project_intakes.create!(
      client: client, title: "Fictional synthetic UX example",
      project_type: "website", goal: "Use fixed unapproved offline templates only.",
      demo_consent_at: Time.current
    )
    @workspace.studio_ai_policies.create!(
      mode: "offline", purposes: %w[clarify source_outline document_proposal]
    )
  end

  test "320 390 430px owner preview record and review remain operable without horizontal overflow" do
    sign_in_as_synthetic_owner
    [320, 390, 430].each_with_index do |width, index|
      emulate_css_viewport!(width)
      visit workspace_ai_settings_url(@workspace, @intake)

      assert_selector "h1", text: "Offline AI settings"
      assert_selector "section[aria-label='Workspace policy'] form"
      assert_selector "section[aria-label='Project restriction'] form"
      assert_selector "section[aria-label='Synthetic offline proposal'] form"
      assert_selector "section[aria-label='Synthetic run history']"
      assert_selector "label[for='offline_purpose']", text: "Proposal type"
      assert_selector "label[for='workspace_mode']", text: "AI mode"
      assert_no_selector "script[src*='api.openai.com']"
      assert_fits_mobile_width(width)

      select "Clarify", from: "Proposal type"
      click_button "Generate synthetic offline preview"
      assert_selector "[aria-label='Unapproved offline proposal']", text: "Needs human review"
      assert_text "0 external calls"
      assert_text "$0 cost"
      assert_button "Record this synthetic run for review"
      assert_fits_mobile_width(width)

      click_button "Record this synthetic run for review"
      assert_current_path workspace_ai_settings_path(@workspace, @intake)
      assert_selector "section[aria-label='Synthetic run history']", text: "Version #{index + 1}"
      assert_button "Mark reviewed (synthetic only)"
      assert_button "Discard synthetic run"
      assert_fits_mobile_width(width)

      # Only the latest unreviewed run exposes these actions.
      find("section[aria-label='Synthetic run history'] form", match: :first)
        .click_button("Mark reviewed (synthetic only)")
      assert_current_path workspace_ai_settings_path(@workspace, @intake)
      assert_text "Synthetic-only review decision recorded. No client artifact was approved."
      assert_selector "section[aria-label='Synthetic run history']", text: "Reviewed synthetic"
      assert_fits_mobile_width(width)
    end

    assert_equal 3, @workspace.studio_offline_runs.where(project_intake_id: @intake.id).count
    assert_equal 3, Studio::OfflineRunReview.joins(:offline_run)
      .where(studio_offline_runs: { project_intake_id: @intake.id }).count
    assert @workspace.studio_offline_runs.all? { |run| run.verified_payload!.fetch(:billable_usd).zero? }
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "narrow-screen denied preview and tampered history cannot be reviewed" do
    sign_in_as_synthetic_owner
    emulate_css_viewport!(320)
    root = @workspace.studio_ai_policies.find_by!(project_intake_id: nil)
    root.update!(mode: "off")
    visit workspace_ai_settings_url(@workspace, @intake)
    click_button "Generate synthetic offline preview"
    assert_selector "[role='alert']", text: /Offline proposal rejected/
    assert_no_selector "[aria-label='Unapproved offline proposal']"
    assert_fits_mobile_width(320)

    root.update!(mode: "offline")
    visit workspace_ai_settings_url(@workspace, @intake)
    click_button "Generate synthetic offline preview"
    click_button "Record this synthetic run for review"
    assert_current_path workspace_ai_settings_path(@workspace, @intake)
    assert_text "Synthetic run version 1 recorded for human review."
    run = @workspace.studio_offline_runs.order(version: :desc).first
    run.update_columns(event_digest: "f" * 64) # only disposable test DB

    visit workspace_ai_settings_url(@workspace, @intake)
    assert_selector "[role='alert']", text: /Integrity check failed/
    assert_no_button "Mark reviewed (synthetic only)"
    assert_no_button "Discard synthetic run"
    assert_fits_mobile_width(320)
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  private

  # Resizing a desktop Chrome window can be clamped to a 500px minimum on Linux.
  # Pin CSS viewport metrics directly instead, in both local Chrome and CI headless.
  # This is viewport emulation (not real-device or touch/keyboard acceptance).
  def emulate_css_viewport!(width)
    page.driver.browser.execute_cdp(
      "Emulation.setDeviceMetricsOverride",
      width: width, height: 932, deviceScaleFactor: 1, mobile: false
    )
  end

  def sign_in_as_synthetic_owner
    visit sign_in_url
    fill_in "Email", with: @owner.email
    fill_in "Password", with: @password
    click_button "Sign in"
    assert_current_path consultations_path
  end

  def assert_fits_mobile_width(width)
    metrics = page.evaluate_script(<<~JS)
      (() => {
        const viewport = window.innerWidth;
        const doc = document.documentElement.scrollWidth;
        const buttons = Array.from(document.querySelectorAll(
          "section[aria-label='Synthetic offline proposal'] button, " +
          "section[aria-label='Synthetic run history'] button"
        )).filter(button => button.getClientRects().length);
        const overflowing = buttons.filter(button => {
          const rect = button.getBoundingClientRect();
          return rect.left < -1 || rect.right > viewport + 1;
        }).map(button => button.textContent.trim());
        const primary = document.querySelector("main#main-content");
        return {
          viewport, doc, overflowing, hasMain: !!primary,
          hasVisibleSkipLink: !!document.querySelector("a.skip-link[href='#main-content']")
        };
      })()
    JS
    assert_in_delta width, metrics.fetch("viewport"), 1,
                    "Chrome did not emulate the required #{width}px CSS viewport: #{metrics.inspect}"
    assert_operator metrics.fetch("doc"), :<=, metrics.fetch("viewport") + 1,
                    "RC-037 layout overflows at #{width}px: #{metrics.inspect}"
    assert_empty metrics.fetch("overflowing"),
                 "RC-037 buttons clipped at #{width}px: #{metrics.inspect}"
    assert metrics.fetch("hasMain")
    assert metrics.fetch("hasVisibleSkipLink")
  end
end
