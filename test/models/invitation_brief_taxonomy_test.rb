require "test_helper"

class InvitationBriefTaxonomyTest < ActiveSupport::TestCase
  test "whitelisted sections have unique options and icons" do
    assert_equal %w[tasks frontend backend deployment], InvitationBriefTaxonomy.sections.keys
    InvitationBriefTaxonomy.sections.each do |group, options|
      assert options.present?
      assert_equal options.uniq, options
      assert InvitationBriefTaxonomy::ICONS.fetch(group).start_with?("bi-")
    end
  end

  test "only bounded known choices pass the server whitelist" do
    assert InvitationBriefTaxonomy.valid?({ "tasks" => %w[bugfix tests], "backend" => ["rails"] })
    assert InvitationBriefTaxonomy.valid?({})
    refute InvitationBriefTaxonomy.valid?({ "private" => ["secrets"] })
    refute InvitationBriefTaxonomy.valid?({ "tasks" => ["unverified_category"] })
    refute InvitationBriefTaxonomy.valid?({ "tasks" => %w[bugfix bugfix] })
    refute InvitationBriefTaxonomy.valid?({ "backend" => "rails" })
    refute InvitationBriefTaxonomy.valid?(nil)
  end

  test "every choice is translated in all supported locales" do
    %i[en ru hy es].each do |locale|
      InvitationBriefTaxonomy.sections.each do |group, options|
        assert I18n.exists?("e2_builder.sections.#{group}", locale)
        options.each { |option| assert I18n.exists?("e2_builder.options.#{option}", locale) }
      end
    end
  end
end
