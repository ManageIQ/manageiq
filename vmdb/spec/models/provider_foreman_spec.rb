require "spec_helper"

describe ProviderForeman do
  let(:provider) do
    FactoryGirl.build(:foreman_provider)
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
      before { provider.url = "example.com:555" }

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
