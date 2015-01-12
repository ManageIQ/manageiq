require "spec_helper"

describe ProviderForeman do
  let(:provider) { FactoryGirl.build(:provider_foreman) }
  let(:attrs)    { {:base_url => "example.com", :username => "admin", :password => "smartvm", :verify_ssl => nil} }

  describe "#connection_attrs" do
    context "with no port" do
      it "has correct connection attributes" do
        expect(provider.connection_attrs).to eq(attrs)
      end
    end

    context "with a port" do
      before { provider.url = "example.com:555" }

      it "has correct connection attributes" do
        attrs[:base_url] = "example.com:555"
        expect(provider.connection_attrs).to eq(attrs)
      end
    end
  end
end
