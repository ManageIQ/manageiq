RSpec.describe ManageIQ::Providers::InfraManager do
  describe ".ems_timeouts" do
    before do
      stub_settings(:ems => {:ems_amazon => {},
                             :ems_redhat => {:inventory => {:read_timeout => "5.hours"}}})
    end

    it "returns [nil,nil] if provider not present in settings.yml under :ems:" do
      expect(described_class.ems_timeouts(:hello_world)).to eq [nil, nil]
    end

    it "returns [nil, nil] if provider entry exists in settings.yml but no timeout specified" do
      expect(described_class.ems_timeouts(:ems_amazon)).to eq [nil, nil]
    end

    it "returns [nil, nil] if timeout settings for provider exist but no service passed to the method" do
      expect(described_class.ems_timeouts(:ems_redhat)).to eq [nil, nil]
    end

    it "returns timeouts if there are specified and service passed to the method" do
      expect(described_class.ems_timeouts(:ems_redhat, :inventory)).to eq [5.hours, nil]
    end

    it "supports case insensitivity for keys in settings.yml" do
      expect(described_class.ems_timeouts(:ems_redhat, :InVentory)).to eq [5.hours, nil]
    end
  end

  describe '.clusterless_hosts' do
    it "hosts with no ems" do
      ems = FactoryBot.create(:ems_infra)
      host = FactoryBot.create(:host, :ext_management_system => ems)
      FactoryBot.create(:host, :ext_management_system => ems, :ems_cluster => FactoryBot.create(:ems_cluster))

      expect(ems.clusterless_hosts).to eq([host])
    end
  end
end
