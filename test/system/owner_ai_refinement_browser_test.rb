require "application_system_test_case"
require "digest"
require_relative "../support/owner_service_catalogue_test_data"

class OwnerAiRefinementBrowserTest < ApplicationSystemTestCase
  include OwnerServiceCatalogueTestData

  test "owner reviews bounded AI summary before applying only to a private service draft" do
    owner = make_test_owner("ai-refine-browser@example.test")
    workspace, profile, _snapshot, caps = approved_profile_for(owner)
    catalogue = OwnerServices::Catalogue.new(workspace: workspace)
    offering = catalogue.create_draft!(service_fields(caps.first))
    draft = offering.draft_version
    entry = AiSpendEntry.create!(
      professional_profile: profile, operation: OwnerAi::Composer::VERSION,
      model: OwnerAi::Composer::MODEL,
      request_digest: Digest::SHA256.hexdigest("ai-refine-browser-#{owner.id}"),
      status: "settled", reserved_ticks: 10_000, charged_ticks: 10_000,
      result: {
        "heading" => "Proposed synthetic Rails text",
        "draft" => "Review one synthetic Rails defect with minimal steps and one regression test.",
        "questions" => [], "cautions" => [], "next_step" => "Owner verifies work boundaries",
        "purpose" => "service_copy", "profile_version" => 1, "turn" => 1
      }, resolved_at: Time.current
    )
    visit sign_in_path
    fill_in "Email address", with: owner.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path workspace_path

    visit owner_ai_assistant_path(entry_id: entry.id, offering_id: offering.id)
    assert_selector ".wa-ai-apply__comparison"
    assert_selector ".wa-ai-conversation__turn", count: 1
    assert_text draft.excluded_scope

    [390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 900)
      bounds = page.evaluate_script("({page: document.documentElement.scrollWidth, viewport: innerWidth})")
      assert_operator bounds["page"], :<=, bounds["viewport"] + 1
      assert_selector ".wa-ai-apply__comparison"
      assert_selector ".wa-ai-apply__form"
    end
    page.driver.browser.manage.window.resize_to(1400, 900)
    within(".wa-ai-apply__form") do
      fill_in "Review and edit the exact replacement",
              with: "Review one bounded fictional Rails issue and produce regression tests before any handoff."
      check "I have checked the factual claims, scope and limitations. Update only the selected private draft summary."
      click_button "Save to draft"
    end
    assert_current_path owner_service_path(offering)
    offering.reload
    assert_equal "Review one bounded fictional Rails issue and produce regression tests before any handoff.",
                 offering.draft_version.summary
    assert_equal draft.excluded_scope, offering.draft_version.excluded_scope
    assert_nil offering.published_version
  ensure
    page.driver.browser.manage.window.resize_to(1400, 900)
  end
end
