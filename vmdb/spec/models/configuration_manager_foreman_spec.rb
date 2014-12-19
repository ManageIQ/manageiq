require "spec_helper"

describe ConfigurationManagerForeman do
  let(:configuration_manager) do
    described_class.create(:provider => provider)
  end

  describe "#connection_attrs" do
    context "manager with provider" do
      let(:provider) do
        Provider.new.tap { |p| p.stub(:connection_attrs => "ABC") }
      end

      it "delegates configuration attributes" do
        expect(configuration_manager.connection_attrs).to eq("ABC")
      end
    end
  end
end
