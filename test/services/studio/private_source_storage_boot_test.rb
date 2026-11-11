require "test_helper"

class StudioPrivateSourceStorageBootTest < ActiveSupport::TestCase
  setup do
    @previous_backend = ENV["RC_STUDIO_QUARANTINE_BACKEND"]
    ENV["RC_STUDIO_QUARANTINE_BACKEND"] = "disk"
  end

  teardown do
    if @previous_backend.nil?
      ENV.delete("RC_STUDIO_QUARANTINE_BACKEND")
    else
      ENV["RC_STUDIO_QUARANTINE_BACKEND"] = @previous_backend
    end
  end

  test "synthetic disk storage boots when Active Storage configs are not preloaded" do
    # The Rails Blob load hook populates the registry on first access.
    # Do not depend on whether another test happened to touch Blob first.
    previous_config = Rails.application.config.active_storage.service_configurations
    Rails.application.config.active_storage.service_configurations = nil
    key = "q/#{SecureRandom.hex(32)}"
    storage = nil

    begin
      storage = Studio::PrivateSourceStorage.new
      bytes = "# Fictional lazy storage boot only\n"
      assert_equal true, storage.upload!(key: key, bytes: bytes)
      assert_equal bytes, storage.read!(key: key)
      assert_equal true, storage.exists?(key: key)
      storage.delete!(key: key)
      assert_equal false, storage.exists?(key: key)
    ensure
      storage&.delete!(key: key)
      Rails.application.config.active_storage.service_configurations = previous_config
    end
  end

  test "production denial runs before loading the storage registry" do
    Rails.env.stub(:production?, true) do
      assert_raises(Studio::PrivateSourceStorage::Unavailable) do
        Studio::PrivateSourceStorage.new
      end
    end
  end

  test "unknown quarantine backend still fails closed" do
    ENV["RC_STUDIO_QUARANTINE_BACKEND"] = "unknown"
    assert_raises(Studio::PrivateSourceStorage::Unavailable) do
      Studio::PrivateSourceStorage.new
    end
  end
end
