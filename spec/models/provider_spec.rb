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

    it "works with #update_attributes" do
      p = FactoryGirl.build(:provider_ansible_tower)
      p.update_attributes(:verify_ssl => 0)
      p.update_attributes(:verify_ssl => 1)

      expect(Endpoint.find(p.default_endpoint.id).verify_ssl).to eq(1)
    end
  end

  context "#tenant" do
    let(:tenant) { FactoryGirl.create(:tenant) }
    it "has a tenant" do
      provider = FactoryGirl.create(:provider, :tenant => tenant)
      expect(tenant.providers).to include(provider)
    end
  end
end
