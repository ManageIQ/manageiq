describe ManageIQ::Providers::Vmware::CloudManager do
  before(:context) do
    @host = Rails.application.secrets.vmware_cloud.try(:[], 'host') || 'vmwarecloudhost'
    host_uri = URI.parse("https://#{@host}")

    @hostname = host_uri.host
    @port = host_uri.port == 443 ? nil : host_uri.port

    @userid = Rails.application.secrets.vmware_cloud.try(:[], 'userid') || 'VMWARE_CLOUD_USERID'
    @password = Rails.application.secrets.vmware_cloud.try(:[], 'password') || 'VMWARE_CLOUD_PASSWORD'

    VCR.configure do |c|
      # workaround for escaping host in spec/spec_helper.rb
      c.before_playback do |interaction|
        interaction.filter!(CGI.escape(@host), @host)
        interaction.filter!(CGI.escape('VMWARE_CLOUD_HOST'), 'vmwarecloudhost')
      end

      c.filter_sensitive_data('VMWARE_CLOUD_AUTHORIZATION') { Base64.encode64("#{@userid}:#{@password}").chomp }
      c.filter_sensitive_data('VMWARE_CLOUD_INVALIDAUTHORIZATION') { Base64.encode64("#{@userid}:invalid").chomp }
    end
  end

  before(:example) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(
      :ems_vmware_cloud,
      :zone     => zone,
      :hostname => @hostname,
      :port     => @port
    )
  end

  it ".ems_type" do
    expect(described_class.ems_type).to eq('vmware_cloud')
  end

  it ".description" do
    expect(described_class.description).to eq('VMware vCloud')
  end

  it "will verify credentials" do
    VCR.use_cassette("#{described_class.name.underscore}_valid_credentials") do
      @ems.update_authentication(:default => {:userid => @userid, :password => @password})

      expect(@ems.verify_credentials).to eq(true)
    end
  end

  it "will fail to verify invalid credentials" do
    VCR.use_cassette("#{described_class.name.underscore}_invalid_credentials") do
      @ems.update_authentication(:default => {:userid => @userid, :password => 'invalid'})

      expect { @ems.verify_credentials }.to raise_error(
        MiqException::MiqInvalidCredentialsError, 'Login failed due to a bad username or password.')
    end
  end
end
