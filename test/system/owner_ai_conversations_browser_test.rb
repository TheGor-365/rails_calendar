require "application_system_test_case"
require_relative "../support/owner_service_catalogue_test_data"

# Browser-proof of existing C2.1c OWNER chat, not a real provider call.
# All records are synthetic CI/test DB only; no local review/scratch/production.
class OwnerAiConversationsBrowserTest < ApplicationSystemTestCase
  include OwnerServiceCatalogueTestData

  test "owner creates, saves, reloads and archives a FREE note at desktop and mobile" do
    owner = make_test_owner("owner-chat-browser-#{SecureRandom.hex(5)}@example.test")
    owner.create_owner_workspace!

    visit sign_in_path
    fill_in "Email address", with: owner.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path workspace_path

    visit owner_ai_conversations_path
    assert_selector "#owner-ai-conversations"
    within(".wa-threads__new-form") { find("button[type='submit']").click }
    # Wait for the browser's asynchronous POST + Turbo navigation before
    # reading database state; otherwise the first query can race the submit.
    assert_selector ".wa-threads__composer"
    conversation = owner.owner_workspace.owner_ai_conversations.order(:id).last
    assert conversation
    assert_current_path owner_ai_conversation_path(conversation)

    synthetic_note = "SYNTHETIC BROWSER QA: preserve one unpaid owner note"
    within(".wa-threads__composer") do
      fill_in "wa-thread-body", with: synthetic_note
      find("button[name='intent'][value='note']").click
    end
    assert_selector ".wa-threads__message-body", text: synthetic_note
    assert_equal 1, conversation.owner_ai_messages.count
    assert_equal 0, AiSpendEntry.count

    visit owner_ai_conversation_path(conversation)
    assert_selector ".wa-threads__message-body", text: synthetic_note
    assert_equal 1, conversation.reload.owner_ai_messages.count

    [1440, 390, 320].each do |width|
      page.driver.browser.manage.window.resize_to(width, 900)
      visit owner_ai_conversation_path(conversation)
      assert_selector ".wa-threads__message-body", text: synthetic_note
      width_check = page.evaluate_script(
        "({document: document.documentElement.scrollWidth, viewport: innerWidth})"
      )
      assert_operator width_check.fetch("document"), :<=, width_check.fetch("viewport") + 1
    end

    page.driver.browser.manage.window.resize_to(1440, 900)
    find(".wa-threads__list-row .wa-threads__more summary", match: :first).click
    find("form[action='#{archive_owner_ai_conversation_path(conversation)}'] button").click
    assert_selector ".wa-threads__locked"
    assert_equal "archived", conversation.reload.state
    assert_equal 1, conversation.owner_ai_messages.count

    find(".wa-threads__list-row .wa-threads__more summary", match: :first).click
    find("form[action='#{restore_owner_ai_conversation_path(conversation)}'] button").click
    assert_selector ".wa-threads__composer"
    assert_equal "active", conversation.reload.state
    assert_equal 0, AiSpendEntry.count

    page.driver.browser.manage.delete_all_cookies
    visit owner_ai_conversation_path(conversation)
    assert_current_path sign_in_path
    assert_no_text synthetic_note
  ensure
    page.driver.browser.manage.window.resize_to(1400, 900)
  end

  test "verified client cannot open another owner's private chat" do
    owner = make_test_owner("owner-chat-privacy-#{SecureRandom.hex(5)}@example.test")
    workspace = owner.create_owner_workspace!
    private_thread = workspace.owner_ai_conversations.create!(
      title: "SYNTHETIC OWNER PRIVATE CHAT"
    )
    client = make_test_client("client-chat-privacy-#{SecureRandom.hex(5)}@example.test")
    visit sign_in_path
    fill_in "Email address", with: client.email
    fill_in "Password", with: PASSWORD
    click_button "Sign in"
    assert_current_path client_home_path

    visit owner_ai_conversation_path(private_thread)
    # AccountSessions#new redirects an already signed-in client back to
    # their client cabinet; the owner thread must stay completely invisible.
    assert_current_path client_home_path
    assert_no_text "SYNTHETIC OWNER PRIVATE CHAT"
  end
end
