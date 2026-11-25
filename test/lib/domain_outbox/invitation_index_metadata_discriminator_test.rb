require "test_helper"
require "open3"
require "rbconfig"
require_relative "../../../lib/domain_outbox/invitation_index_metadata_discriminator"

class DomainOutboxInvitationIndexMetadataDiscriminatorTest < ActiveSupport::TestCase
  TRIAGE = DomainOutbox::InvitationIndexMetadataTriage
  SUBJECT = DomainOutbox::InvitationIndexMetadataDiscriminator
  OPERATOR = Rails.root.join("script/rc0551f_c23b7l_invitation_index_readonly.rb").to_s

  def fixture
    {"database"=>TRIAGE::TARGET, "role"=>TRIAGE::ROLE, "version_num"=>160011,
     "socket"=>true, "read_only"=>true, "other_sessions"=>0,
     "table_present"=>true, "table_kind"=>"r", "indexes"=>[{
       "name"=>TRIAGE::EXPECTED_INDEX, "valid"=>true, "ready"=>true,
       "unique"=>false, "method"=>"btree", "keys"=>TRIAGE::EXPECTED_KEYS.dup,
       "included_count"=>0, "has_predicate"=>false, "has_expression"=>false
     }]}
  end

  test "C2.3b7l distinguishes alternative name and validity" do
    sample=fixture
    index=sample.fetch("indexes").first
    index["name"]="idx_alternative_workspace_created"
    assert_equal "INDEX_NAME_OR_DEFINITION_DRIFT", TRIAGE.classify(sample)
    assert_equal "ALTERNATE_NAME_VALID_READY", SUBJECT.evaluate(sample).fetch(:variant)
    assert_equal "idx_alternative_workspace_created", SUBJECT.evaluate(sample).fetch(:name)
    index["ready"]=false
    assert_equal "ALTERNATE_NAME_INVALID_OR_NOT_READY", SUBJECT.evaluate(sample).fetch(:variant)
    index["ready"]=true
    index["valid"]=false
    assert_equal "ALTERNATE_NAME_INVALID_OR_NOT_READY", SUBJECT.evaluate(sample).fetch(:variant)
  end

  test "C2.3b7l reports exact-name definition deltas" do
    {"keys"=>["created_at","workspace_id"],"method"=>"hash",
     "included_count"=>1,"has_predicate"=>true,"has_expression"=>true}.each do |key,value|
      sample=fixture
      sample.fetch("indexes").first[key]=value
      result=SUBJECT.evaluate(sample)
      assert_equal "EXPECTED_NAME_DEFINITION_DRIFT", result.fetch(:variant)
      label={"keys"=>"KEYS","method"=>"METHOD","included_count"=>"INCLUDED_COUNT",
             "has_predicate"=>"PREDICATE","has_expression"=>"EXPRESSION"}.fetch(key)
      assert_includes result.fetch(:delta).split(","), label
    end
  end

  test "C2.3b7l rejects stale, malformed and multiple alternate metadata" do
    assert_nil SUBJECT.evaluate(fixture)
    sample=fixture
    sample["other_sessions"]=1
    assert_nil SUBJECT.evaluate(sample)
    sample=fixture
    sample.fetch("indexes").first.delete("valid")
    assert_nil SUBJECT.evaluate(sample)
    sample=fixture
    sample.fetch("indexes").first["name"]="idx_one"
    another=Marshal.load(Marshal.dump(sample.fetch("indexes").first))
    another["name"]="idx_two"
    sample.fetch("indexes") << another
    assert_equal "MULTIPLE_ALTERNATE_MATCHES", SUBJECT.evaluate(sample).fetch(:variant)
  end

  test "C2.3b7l operator blocks no approval and production" do
    env={"RC_APPROVE_C23B7L_INDEX_READ"=>nil,"RC_REVIEWED_SCRATCH_NAME"=>nil,
         "RC_EXPECTED_HEAD_SHA"=>nil,"RAILS_ENV"=>nil,"RACK_ENV"=>nil}
    out,err,status=Open3.capture3(env,RbConfig.ruby,OPERATOR)
    assert_not status.success?
    assert_empty out
    assert_includes err,"new, separate one-query authorization missing"
    env["RC_APPROVE_C23B7L_INDEX_READ"]="YES_ONE_C23B7L_INDEX_CATALOG_READ"
    env["RC_REVIEWED_SCRATCH_NAME"]=TRIAGE::TARGET
    out,err,status=Open3.capture3(env.merge("RAILS_ENV"=>"production"),RbConfig.ruby,OPERATOR)
    assert_not status.success?
    assert_empty out
    assert_includes err,"development-only context"
  end
end
