require "application_system_test_case"

# Browser evidence for a TEST-ONLY fictional owner interface, not production UI.
class StudioProjectHubBrowserTest < ApplicationSystemTestCase
  setup do
    suffix = SecureRandom.hex(5)
    @password = "rc039-browser-fictional-owner-password"
    @owner = User.create!(email: "hub-browser-#{suffix}@example.test", role: "owner",
      password: @password, password_confirmation: @password)
    @workspace = Workspace.create!(owner_user: @owner, name: "Fictional browser hub",
      slug: "hub-browser-#{suffix}")
    WorkspaceMembership.create!(workspace: @workspace, user: @owner,
      role: "owner", status: "active")
    client = @workspace.clients.create!(display_name: "Private fictional customer")
    @intake = @workspace.project_intakes.create!(
      client: client, title: "Secret fictional case study", project_type: "website",
      goal: "No real project or customer content in this board.",
      demo_consent_at: Time.current
    )
    @url = rc039_synthetic_project_hub_preview_path(@workspace, client, @intake)
  end

  test "320 390 430px owner can create and transition fictional cards without horizontal overflow" do
    visit sign_in_url
    fill_in "Email", with: @owner.email
    fill_in "Password", with: @password
    click_button "Sign in"
    assert_current_path consultations_path

    [320, 390, 430].zip(%w[discovery_brief requirements_spec full_roadmap]).each do |width, key|
      emulate_viewport!(width)
      visit @url
      assert_selector "h1", text: "Project Hub preview"
      assert_selector "section.rc-hub-lane", count: 4
      assert_selector "li.rc-hub-card", count: 9
      assert_selector "[aria-label='Project Hub safety limits']"
      refute_text @intake.title
      assert_safe_width(width)

      within "[data-artifact-key='#{key}']" do
        click_button "Create synthetic card"
      end
      assert_current_path @url
      assert_text "Fictional card recorded. No scope approved."
      within "[data-artifact-key='#{key}']" do
        assert_text "Backlog"
        select "In review", from: "Move to"
        click_button "Move synthetic card"
      end
      assert_current_path @url
      assert_text "Fictional card state recorded. No approval granted."
      within "[data-artifact-key='#{key}']" do
        assert_text "In review"
        assert_text "Revision 1"
      end
      assert_safe_width(width)
    end
    assert_equal 3, Studio::SyntheticProjectCard.count
    assert_equal 3, Studio::SyntheticProjectCardTransition.count
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  test "keyboard opens prerequisite disclosure without pointer and leaves no approval controls" do
    visit sign_in_url
    fill_in "Email", with: @owner.email
    fill_in "Password", with: @password
    click_button "Sign in"
    assert_current_path consultations_path

    emulate_viewport!(320)
    visit @url
    details = find("[data-artifact-key='requirements_spec'] details.rc-hub-details")
    assert_no_selector "[data-artifact-key='requirements_spec'] details[open]"
    details.find("summary").send_keys(:enter)
    assert_selector "[data-artifact-key='requirements_spec'] details[open]"
    assert_selector "[data-artifact-key='requirements_spec'] details li", minimum: 1
    assert_selector "[data-artifact-key='requirements_spec'] h3[id='hub_artifact_requirements_spec']"
    assert_selector "[data-artifact-key='requirements_spec'] button[aria-describedby='hub_artifact_requirements_spec']"
    assert_no_button "Approve scope"
    assert_no_button "Upload client file"
    assert_safe_width(320)
  ensure
    page.driver.browser.execute_cdp("Emulation.clearDeviceMetricsOverride")
  end

  private

  def emulate_viewport!(width)
    page.driver.browser.execute_cdp("Emulation.setDeviceMetricsOverride",
      width: width, height: 932, deviceScaleFactor: 1, mobile: false)
  end

  def assert_safe_width(width)
    values = page.evaluate_script(<<~JS)
      (() => {
        const viewport = window.innerWidth;
        const all = Array.from(document.querySelectorAll(
          ".rc-project-hub button, .rc-project-hub select, .rc-project-hub summary"
        )).filter(x => x.getClientRects().length);
        const clipped = all.filter(x => {
          const r = x.getBoundingClientRect();
          return r.left < -1 || r.right > viewport + 1;
        }).map(x => x.textContent.trim()).slice(0, 5);
        return {viewport, doc: document.documentElement.scrollWidth, clipped};
      })()
    JS
    assert_in_delta width, values.fetch("viewport"), 1, values.inspect
    assert_operator values.fetch("doc"), :<=, values.fetch("viewport") + 1, values.inspect
    assert_empty values.fetch("clipped"), values.inspect
  end
end
