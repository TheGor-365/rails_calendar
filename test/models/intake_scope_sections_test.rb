require "test_helper"

class IntakeScopeSectionsTest < ActiveSupport::TestCase
  test "twelve ordered domains cover client and developer discovery" do
    assert_equal 12, IntakeScopeSections::KEYS.size
    assert_equal "business_goal", IntakeScopeSections::KEYS.first
    assert_equal "estimate", IntakeScopeSections::KEYS.last
    assert_equal 12, IntakeScopeSections::ITEMS.values.uniq.size
  end

  test "normalization accepts plain client text delegated to developer" do
    normalized = IntakeScopeSections.normalize({
      "business_goal" => {
        "text" => "  Visitors should receive confirmation.  ",
        "status" => "suggested", "responsibility" => "owner"
      },
      "data" => { "text" => "", "status" => "unknown", "responsibility" => "open" }
    })
    assert_equal "Visitors should receive confirmation.",
      normalized.fetch("business_goal").fetch("text")
    assert_equal "owner", normalized.fetch("business_goal").fetch("responsibility")
    assert_equal "unknown", normalized.fetch("data").fetch("status")
  end

  test "forged keys, values and oversized answers are rejected" do
    assert_nil IntakeScopeSections.normalize({ "owner_secrets" => { "text" => "x" } })
    assert_nil IntakeScopeSections.normalize({ "features" => { "text" => "x", "status" => "approved" } })
    assert_nil IntakeScopeSections.normalize({ "features" => { "text" => "x", "responsibility" => "admin" } })
    assert_nil IntakeScopeSections.normalize({ "features" => { "text" => "x" * 1601 } })
    assert_nil IntakeScopeSections.normalize({ "features" => { "text" => "ok", "extra" => true } })
  end
end
