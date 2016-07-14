describe ManageIQ::Providers::Vmware::CloudManager do
  it ".ems_type" do
    expect(described_class.ems_type).to eq('vmware_cloud')
  end

  it ".description" do
    expect(described_class.description).to eq('VMware vCloud Director')
  end

  it "will verify credentials" do
    VCR.use_cassette("#{described_class.name.underscore}_valid_credentials") do
      _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
      ems = FactoryGirl.create(
        :ems_vmware_cloud,
        :zone     => zone,
        :hostname => 'localhost',
        :port     => 1284
      )
      ems.update_authentication(:default => {:userid => 'admin@org', :password => 'password'})

      expect(ems.verify_credentials).to eq(true)
    end
  end

  it "will fail to verify invalid credentials" do
    VCR.use_cassette("#{described_class.name.underscore}_invalid_credentials") do
      _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
      ems = FactoryGirl.create(
        :ems_vmware_cloud,
        :zone     => zone,
        :hostname => 'localhost',
        :port     => 1284
      )
      ems.update_authentication(:default => {:userid => 'admin@org', :password => 'invalid'})

      expect { ems.verify_credentials }.to raise_error(
        MiqException::MiqInvalidCredentialsError, 'Login failed due to a bad username or password.')
    end
  end
end
