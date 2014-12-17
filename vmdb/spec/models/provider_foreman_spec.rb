require "spec_helper"

describe ProviderForeman do
  let(:authentication) do
    FactoryGirl.create(:authentication, :userid => "testuser", :password => "secret")
  end

  let(:provider) do
    described_class.new(:name => "x", :hostname => "example.com").tap do |csf|
      csf.authentications << authentication
    end
  end

  describe "#connection_attrs" do
    context "with no port" do
      it "has all authentication attributes" do
        expect(provider.connection_attrs).to eq(
          :base_url   => "example.com",
          :username   => "testuser",
          :password   => "secret",
          :verify_ssl => nil
        )
      end
    end

    context "with a port" do
      before { provider.port = 555 }

      it "has all authentication attributes" do
        expect(provider.connection_attrs).to eq(
          :base_url   => "example.com:555",
          :username   => "testuser",
          :password   => "secret",
          :verify_ssl => nil
        )
      end
    end
  end
end
