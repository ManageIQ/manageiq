require "spec_helper"

require "manageiq_foreman"

describe ProviderForeman do
  let(:provider) { FactoryGirl.build(:provider_foreman) }
  let(:attrs)    { {:base_url => "example.com", :username => "admin", :password => "smartvm", :verify_ssl => nil} }

  describe "#connect" do
    it "with no port" do
      expect(ManageiqForeman::Connection).to receive(:new).with(attrs)
      provider.connect
    end

    it "with a port" do
      provider.url = "example.com:555"
      attrs[:base_url] = "example.com:555"

      expect(ManageiqForeman::Connection).to receive(:new).with(attrs)
      provider.connect
    end
  end

  describe "#destroy" do
    it "will remove all child objects" do
      provider = FactoryGirl.create(:provider_foreman, :zone => FactoryGirl.create(:zone))

      provider.configuration_manager.configured_systems = [
        FactoryGirl.create(:configured_system, :computer_system =>
          FactoryGirl.create(:computer_system,
            :operating_system => FactoryGirl.create(:operating_system),
            :hardware         => FactoryGirl.create(:hardware),
          )
        )
      ]
      provider.configuration_manager.configuration_profiles =
        [FactoryGirl.create(:configuration_profile)]
      provider.provisioning_manager.operating_system_flavors =
        [FactoryGirl.create(:operating_system_flavor)]
      provider.provisioning_manager.customization_scripts =
        [FactoryGirl.create(:customization_script)]

      provider.destroy

      expect(Provider.count).to              eq(0)
      expect(ConfiguredSystem.count).to      eq(0)
      expect(ComputerSystem.count).to        eq(0)
      expect(OperatingSystem.count).to       eq(0)
      expect(Hardware.count).to              eq(0)
      expect(ConfigurationProfile.count).to  eq(0)
      expect(OperatingSystemFlavor.count).to eq(0)
      expect(CustomizationScript.count).to   eq(0)
    end
  end
end
