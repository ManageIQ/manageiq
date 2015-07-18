require "spec_helper"
require Rails.root.join("db/migrate/20150501193927_default_provider_verify_ssl")

describe DefaultProviderVerifySsl do
  migration_context :up do
    let(:provider_stub) { migration_stub(:Provider) }

    it "resets nil values to OpenSSL::SSL::VERIFY_PEER" do
      changed = provider_stub.create!(:verify_ssl => nil)
      ignored = provider_stub.create!(:verify_ssl => OpenSSL::SSL::VERIFY_NONE)

      migrate

      expect(changed.reload.verify_ssl).to eq OpenSSL::SSL::VERIFY_PEER
      expect(ignored.reload.verify_ssl).to eq OpenSSL::SSL::VERIFY_NONE
    end
  end
end
