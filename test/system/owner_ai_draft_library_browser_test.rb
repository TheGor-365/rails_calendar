require "application_system_test_case"
require "digest"
require_relative "../support/owner_service_catalogue_test_data"

class OwnerAiDraftLibraryBrowserTest < ApplicationSystemTestCase
  include OwnerServiceCatalogueTestData

  test "owner can reopen saved private AI draft with no paid request on desktop or mobile" do
    owner = make_test_owner("ai-draft-library-browser@example.test")
    _workspace, profile, = approved_profile_for(owner)
    entry = AiSpendEntry.create!(
      professional_profile: profile, operation: OwnerAi::Composer::VERSION,
      model: OwnerAi::Composer::MODEL,
      request_digest: Digest::SHA256.hexdigest("ai-draft-library-browser-#{owner.id}"),
      status: "settled", reserved_ticks: 10_000, charged_ticks: 10_000,
      result: {
        "heading" => "A saved synthetic Rails draft",
        "draft" => "A bounded fictional Rails service with explicit client acceptance conditions.",
        "questions" => [], "cautions" => [], "next_step" => "Owner reviews",
        "purpose" => "service_copy", "profile_version" => 1, "turn" => 1
      }, resolved_at: Time.current
    )

    visit sign_in_path
    fill_in "Email address", with: owner.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path workspace_path
    visit owner_ai_assistant_path

    assert_selector "#owner-ai-draft-library"
    assert_text "A saved synthetic Rails draft"
    [390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 900)
      bounds = page.evaluate_script("({page: document.documentElement.scrollWidth, viewport: innerWidth})")
      assert_operator bounds["page"], :<=, bounds["viewport"] + 1
      assert_selector ".wa-ai-draft-library__item", count: 1
    end

    within("#owner-ai-draft-library") do
      click_link "Open draft"
    end
    assert_current_path owner_ai_assistant_path(entry_id: entry.id, operation: "service_copy")
    assert_selector ".wa-ai-page__draft", text: /bounded fictional Rails service/
    assert_selector "#owner-ai-draft-library"
  ensure
    page.driver.browser.manage.window.resize_to(1400, 900)
  end
end
