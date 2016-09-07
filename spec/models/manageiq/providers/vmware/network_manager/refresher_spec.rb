describe ManageIQ::Providers::Vmware::NetworkManager::Refresher do
  before do
    @host = Rails.application.secrets.vmware_cloud.try(:[], 'host') || 'vmwarecloudhost'
    host_uri = URI.parse("https://#{@host}")

    @hostname = host_uri.host
    @port = host_uri.port == 443 ? nil : host_uri.port

    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(
      :ems_vmware_cloud,
      :zone     => zone,
      :hostname => @hostname,
      :port     => @port
    )
    @ems_network = @ems.network_manager
    @network_type_vdc = "ManageIQ::Providers::Vmware::NetworkManager::CloudNetwork::OrgVdcNet"
    @network_type_vapp = "ManageIQ::Providers::Vmware::NetworkManager::CloudNetwork::VappNet"

    @userid = Rails.application.secrets.vmware_cloud.try(:[], 'userid') || 'VMWARE_CLOUD_USERID'
    @password = Rails.application.secrets.vmware_cloud.try(:[], 'password') || 'VMWARE_CLOUD_PASSWORD'

    VCR.configure do |c|
      # workaround for escaping host in spec/spec_helper.rb
      c.before_playback do |interaction|
        interaction.filter!(CGI.escape(@host), @host)
        interaction.filter!(CGI.escape('VMWARE_CLOUD_HOST'), 'vmwarecloudhost')
      end

      c.filter_sensitive_data('VMWARE_CLOUD_AUTHORIZATION') { Base64.encode64("#{@userid}:#{@password}").chomp }
    end

    cred = {
      :userid   => @userid,
      :password => @password
    }

    @ems.authentications << FactoryGirl.create(:authentication, cred)
  end

  it ".ems_type" do
    expect(described_class.ems_type).to eq(:vmware_cloud_network)
  end

  it "will perform a full refresh" do
    2.times do # Run twice to verify that a second run with existing data does not change anything
      @ems.reload
      @ems_network.reload
      VCR.use_cassette(described_class.name.underscore, :allow_unused_http_interactions => true) do
        EmsRefresh.refresh(@ems)
        EmsRefresh.refresh(@ems_network)
      end
      @ems.reload
      @ems_network.reload

      assert_network_counts
      assert_specific_network_tree_vdc
      assert_specific_network_tree_vapp
    end
  end

  def assert_network_counts
    expect(CloudNetwork.count).to eq(7)
    expect(CloudNetwork.where(:type => @network_type_vdc).count).to eq(2)
    expect(CloudNetwork.where(:type => @network_type_vapp).count).to eq(5)
    expect(CloudSubnet.count).to eq(7)
    expect(NetworkPort.count).to eq(8)
  end

  def assert_specific_network_tree_vdc
    n = CloudNetwork.where(:name => "vdc-net-miha").first
    expect(n).to be
    expect(n).to have_attributes(
      :enabled => true,
      :shared  => false,
      :type    => @network_type_vdc,
    )

    expect(n.cloud_subnets.count).to eq(1)
    subn = n.cloud_subnets.first
    expect(subn).to have_attributes(
      :gateway         => "10.30.2.1",
      :dns_nameservers => ["8.8.8.8", "8.8.4.4"]
    )

    expect(subn.network_ports.count).to eq(2)
    port = subn.network_ports.find { |p| p.name == "TTYLinux-1-mm#NIC#0" }
    expect(port).to have_attributes(
      :name => "TTYLinux-1-mm#NIC#0",
    )

    expect(subn.vms.count).to eq(2)
    vm = subn.vms.second
    expect(vm).to have_attributes(
      :name => "Damn Small Linux-mm",
    )
  end

  def assert_specific_network_tree_vapp
    n = CloudNetwork.where(:name => "vapp-network-miha (mihap_vApp_networking)").first
    expect(n).to be
    expect(n).to have_attributes(
      :enabled => true,
      :shared  => nil,
      :type    => @network_type_vapp,
    )

    expect(n.cloud_subnets.count).to eq(1)
    subn = n.cloud_subnets.first
    expect(subn).to have_attributes(
      :gateway         => nil,
      :dns_nameservers => [nil, nil]
    )

    expect(subn.network_ports.count).to eq(2)
    port = subn.network_ports.find { |p| p.name == "TTYLinux-2-mm#NIC#0" }
    expect(port).to have_attributes(
      :name => "TTYLinux-2-mm#NIC#0",
    )

    expect(subn.vms.count).to eq(2)
    vm = subn.vms.first
    expect(vm).to have_attributes(
      :name => "TTYLinux-2-mm",
    )
  end
end
