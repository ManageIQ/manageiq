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
end
