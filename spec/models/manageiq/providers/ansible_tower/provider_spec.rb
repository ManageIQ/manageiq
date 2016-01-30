require "ansible_tower_client"

describe ManageIQ::Providers::AnsibleTower::Provider do
  describe "#connect" do
    let(:provider) { FactoryGirl.build(:provider_ansible_tower) }
    let(:attrs)    { {:base_url => "example.com", :username => "admin", :password => "smartvm", :verify_ssl => OpenSSL::SSL::VERIFY_PEER} }

    it "with no port" do
      expect(AnsibleTowerClient::Connection).to receive(:new).with(attrs)
      provider.connect(attrs)
    end

    it "with a port" do
      provider.url     = "example.com:555"
      attrs[:base_url] = "example.com:555"

      expect(AnsibleTowerClient::Connection).to receive(:new).with(attrs)
      provider.connect(attrs)
    end
  end

  describe "#destroy" do
    it "will remove all child objects" do
      provider = FactoryGirl.create(:provider_ansible_tower, :zone => FactoryGirl.create(:zone))

      provider.configuration_manager.configured_systems = [
        FactoryGirl.create(:configured_system, :computer_system =>
          FactoryGirl.create(:computer_system,
                             :operating_system => FactoryGirl.create(:operating_system),
                             :hardware         => FactoryGirl.create(:hardware),
                            )
                          )
      ]

      provider.destroy

      expect(Provider.count).to              eq(0)
      expect(ConfiguredSystem.count).to      eq(0)
      expect(ComputerSystem.count).to        eq(0)
      expect(OperatingSystem.count).to       eq(0)
      expect(Hardware.count).to              eq(0)
    end
  end
end
