RSpec.describe Vmdb::Initializer do
  describe ".init_secret_token" do
    before do
      @token = Rails.application.secret_key_base
    end

    after do
      Rails.application.config.secret_key_base = @token
      Rails.application.secrets = nil
    end

    it "defaults to MiqDatabase session_secret_token" do
      MiqDatabase.seed
      Rails.application.config.secret_key_base = nil
      Rails.application.secrets = nil

      described_class.init_secret_token
      expect(Rails.application.secret_key_base).to eq(MiqDatabase.first.session_secret_token)
      expect(Rails.application.config.secret_key_base).to eq(MiqDatabase.first.session_secret_token)
    end

    it "uses random hex when MiqDatabase isn't seeded" do
      Rails.application.config.secret_key_base = nil
      Rails.application.secrets = nil

      described_class.init_secret_token
      expect(Rails.application.secret_key_base).to match(/^\h{128}$/)
      expect(Rails.application.config.secret_key_base).to match(/^\h{128}$/)
    end

    it "does not reset secrets when token already configured" do
      existing_value = SecureRandom.hex(64)
      Rails.application.config.secret_key_base = existing_value
      Rails.application.secrets = nil

      described_class.init_secret_token
      expect(Rails.application.secret_key_base).to eq(existing_value)
      expect(Rails.application.config.secret_key_base).to eq(existing_value)
    end

    it "uses random hex when MiqDatabase is seeded with invalid session_secret_token" do
      MiqDatabase.seed.tap do |d|
        d.session_secret_token_encrypted = "xxx"
        d.save!(validate: false)
      end
      Rails.application.config.secret_key_base = nil
      Rails.application.secrets = nil
      expect(described_class).to receive(:log_error_and_tty_aware_warn).at_least(:once)

      described_class.init_secret_token
      expect(Rails.application.secret_key_base).to match(/^\h{128}$/)
      expect(Rails.application.config.secret_key_base).to match(/^\h{128}$/)
    end
  end
end
