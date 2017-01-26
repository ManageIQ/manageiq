require "ansible_tower_client"

describe ManageIQ::Providers::AnsibleTower::Provider do
  subject { FactoryGirl.build(:provider_ansible_tower) }

  describe "#connect" do
    let(:attrs) { {:username => "admin", :password => "smartvm", :verify_ssl => OpenSSL::SSL::VERIFY_PEER} }

    it "with no port" do
      url = "example.com"

      expect(AnsibleTowerClient::Connection).to receive(:new).with(attrs.merge(:base_url => url))
      subject.connect(attrs.merge(:url => url))
    end

    it "with a port" do
      url = "example.com:555"

      expect(AnsibleTowerClient::Connection).to receive(:new).with(attrs.merge(:base_url => url))
      subject.connect(attrs.merge(:url => url))
    end
  end

  describe "#destroy" do
    it "will remove all child objects" do
      provider = FactoryGirl.create(:provider_ansible_tower, :zone => FactoryGirl.create(:zone))

      provider.automation_manager.configured_systems = [
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

  context "#url=" do
    it "with full URL" do
      subject.url = "https://server.example.com:1234/api/v1"
      expect(subject.url).to eq("https://server.example.com:1234/api/v1")
    end

    it "missing scheme" do
      subject.url = "server.example.com:1234/api/v1"
      expect(subject.url).to eq("https://server.example.com:1234/api/v1")
    end

    it "works with #update_attributes" do
      subject.update_attributes(:url => "server.example.com")
      subject.update_attributes(:url => "server2.example.com")
      expect(Endpoint.find(subject.default_endpoint.id).url).to eq("https://server2.example.com/api/v1")
    end
  end

  it "with only hostname" do
    subject.url = "server.example.com"
    expect(subject.url).to eq("https://server.example.com/api/v1")
  end
end
