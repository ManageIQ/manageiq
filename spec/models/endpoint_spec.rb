require "spec_helper"

describe Endpoint do
  let(:endpoint) { described_class.new }

  describe "#verify_ssl" do
    context "when non set" do
      it "is default to verify ssl" do
        expect(endpoint.verify_ssl).to eq(OpenSSL::SSL::VERIFY_PEER)
        expect(endpoint).to be_verify_ssl
      end
    end

    context "when set to false" do
      before { endpoint.verify_ssl = false }

      it "is verify none" do
        expect(endpoint.verify_ssl).to eq(OpenSSL::SSL::VERIFY_NONE)
        expect(endpoint).not_to be_verify_ssl
      end
    end

    context "when set to true" do
      before { endpoint.verify_ssl = true }

      it "is verify peer" do
        expect(endpoint.verify_ssl).to eq(OpenSSL::SSL::VERIFY_PEER)
        expect(endpoint).to be_verify_ssl
      end
    end

    context "when set to verify none" do
      before { endpoint.verify_ssl = OpenSSL::SSL::VERIFY_NONE }

      it "is verify none" do
        expect(endpoint.verify_ssl).to eq(OpenSSL::SSL::VERIFY_NONE)
        expect(endpoint).not_to be_verify_ssl
      end
    end

    context "when set to verify peer" do
      before { endpoint.verify_ssl = OpenSSL::SSL::VERIFY_PEER }

      it "is verify peer" do
        expect(endpoint.verify_ssl).to eq(OpenSSL::SSL::VERIFY_PEER)
        expect(endpoint).to be_verify_ssl
      end
    end
  end

  it "#port returns nil for port 0 in the db" do
    allow(MiqServer).to receive(:my_zone).and_return("default")
    rhev = FactoryGirl.create(:ems_redhat_with_authentication)
    Endpoint.update_all(:port => 0)
    rhev.reload
    expect(rhev.class).to receive(:raw_connect).with(rhev.address, nil, any_args)
    rhev.authentication_check
  end

  it "#port returns the real value for other than 0" do
    allow(MiqServer).to receive(:my_zone).and_return("default")
    rhev = FactoryGirl.create(:ems_redhat_with_authentication)
    Endpoint.update_all(:port => 443)
    rhev.reload
    expect(rhev.class).to receive(:raw_connect).with(rhev.address, 443, any_args)
    rhev.authentication_check
  end
end
