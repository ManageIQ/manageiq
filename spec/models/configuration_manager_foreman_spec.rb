require "spec_helper"

describe ManageIQ::Providers::Foreman::ConfigurationManager do
  let(:provider) { FactoryGirl.build(:provider_foreman) }
  let(:configuration_manager) do
    FactoryGirl.build(:configuration_manager_foreman, :provider => provider)
  end

  describe "#connect" do
    it "delegates to the provider" do
      expect(provider).to receive(:connect)
      configuration_manager.connect
    end
  end
end
