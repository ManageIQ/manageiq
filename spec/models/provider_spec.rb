require "spec_helper"

describe Provider do
  let(:provider) { described_class.new }

  describe "#verify_ssl" do
    context "when non set" do
      it "is default to verify ssl" do
        expect(provider.verify_ssl).to eq(OpenSSL::SSL::VERIFY_PEER)
        expect(provider).to be_verify_ssl
      end
    end

    context "when set to false" do
      before { provider.verify_ssl = false }

      it "is verify none" do
        expect(provider.verify_ssl).to eq(OpenSSL::SSL::VERIFY_NONE)
        expect(provider).not_to be_verify_ssl
      end
    end

    context "when set to true" do
      before { provider.verify_ssl = true }

      it "is verify peer" do
        expect(provider.verify_ssl).to eq(OpenSSL::SSL::VERIFY_PEER)
        expect(provider).to be_verify_ssl
      end
    end

    context "when set to verify none" do
      before { provider.verify_ssl = OpenSSL::SSL::VERIFY_NONE }

      it "is verify none" do
        expect(provider.verify_ssl).to eq(OpenSSL::SSL::VERIFY_NONE)
        expect(provider).not_to be_verify_ssl
      end
    end

    context "when set to verify peer" do
      before { provider.verify_ssl = OpenSSL::SSL::VERIFY_PEER }

      it "is verify peer" do
        expect(provider.verify_ssl).to eq(OpenSSL::SSL::VERIFY_PEER)
        expect(provider).to be_verify_ssl
      end
    end
  end

  context "#tenant_owner" do
    let(:tenant) { FactoryGirl.create(:tenant) }
    it "has a tenant owner" do
      provider = FactoryGirl.create(:provider, :tenant_owner => tenant)
      expect(tenant.owned_providers).to include(provider)
    end
  end

  context "#tenants" do
    let(:tenant) { FactoryGirl.create(:tenant) }
    it "has a tenant owner" do
      provider = FactoryGirl.create(:provider)
      provider.tenants << tenant
      expect(tenant.providers).to include(provider)
    end
  end
end
