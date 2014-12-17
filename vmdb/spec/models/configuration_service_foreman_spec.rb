require "spec_helper"

describe ConfigurationServiceForeman do
  let(:configuration_service) do
    described_class.create(:provider => provider)
  end

  describe "#connection_attrs" do
    context "service with provider" do
      let(:provider) do
        Provider.new.tap { |p| p.stub(:connection_attrs => "ABC") }
      end

      it "delegates configuration attributes" do
        expect(configuration_service.connection_attrs).to eq("ABC")
      end
    end
  end
end
