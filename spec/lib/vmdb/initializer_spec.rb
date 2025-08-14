RSpec.describe Vmdb::Initializer do
  describe ".init_secret_token" do
    around do |example|
      token = Rails.application.config.secret_key_base
      example.run
    ensure
      Rails.application.config.secret_key_base = token
    end

    it "defaults to MiqDatabase session_secret_token" do
      MiqDatabase.seed

      described_class.init_secret_token
      expect(Rails.application.secret_key_base).to eq(MiqDatabase.first.session_secret_token)
      expect(Rails.application.config.secret_key_base).to eq(MiqDatabase.first.session_secret_token)
    end

    it "running init_secret_token a second time will not change the token" do
      MiqDatabase.seed
      Rails.application.config.secret_key_base = MiqDatabase.first.session_secret_token

      described_class.init_secret_token
      expect(Rails.application.secret_key_base).to eq(MiqDatabase.first.session_secret_token)
      expect(Rails.application.config.secret_key_base).to eq(MiqDatabase.first.session_secret_token)
    end

    it "uses random hex when MiqDatabase isn't seeded" do
      described_class.init_secret_token
      expect(Rails.application.secret_key_base).to match(/^\h{128}$/)
      expect(Rails.application.config.secret_key_base).to match(/^\h{128}$/)
    end

    it "uses random hex when MiqDatabase is seeded with invalid session_secret_token" do
      MiqDatabase.seed.tap do |d|
        d.session_secret_token_encrypted = "xxx"
        d.save!(validate: false)
      end
      expect(described_class).to receive(:log_error_and_tty_aware_warn).at_least(:once)

      described_class.init_secret_token
      expect(Rails.application.secret_key_base).to match(/^\h{128}$/)
      expect(Rails.application.config.secret_key_base).to match(/^\h{128}$/)
    end
  end
end
