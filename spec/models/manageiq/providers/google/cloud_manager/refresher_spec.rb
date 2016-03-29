require 'fog/google'

describe ManageIQ::Providers::Google::CloudManager::Refresher do
  before(:each) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @google_json_key = "{\r\n  \"type\": \"service_account\",\r\n  \"project_id\": \"civil-tube-113314\",\r\n  \"private_key_id\": \"b30f7f40eb725006e658bc5bd2f58200df81280a\",\r\n  \"private_key\": \"-----BEGIN PRIVATE KEY-----\\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC0yjlFvsDexy22\\nAdXET0ptuS1r091fQn3RREbmZsbLvlxiRfdySJpnkOv8fmzoz7/1q1vxGhnftA9S\\nPyxCz1WSc/JDac8iybh5/zg96oFk9rq6VVc7lGy/i9igrxQzyzkPIuS0g0Y1OzRz\\nRro+AKBLgKcejd6EZ16jJWYRgAtD4c2CWizYCFNfHJzn/e8mBWGWYdmqr6VxaXNf\\nBesL+aF/FimAvCEwW1zbXZEkq6vMzlNdUO3EvpDr+yfHdjre+KcflrxVdr6Ju9QD\\nHlAENgP78cZNL1Gk4Os1wSMf8GQV4yKRO/wAGJI4KS4Id8iijwjWhDHCJgdfPNmt\\na/qpX+YdAgMBAAECggEAASXHd0ner4tUHvOkB7r5Hfku8KBHp3MkmU91o8DDQkfT\\nDkyjZXZQhJfG57NlvZSUA1szGjSwNVtPPZZpEYN/Z46U2xiw1+ev5BZapQn4CEwI\\no2YnR5mJly2sElkKJ8oCcrYl/X9X0r6tdo3cYMhgPBp09RyxbOW7FA4It9O4PpYN\\nmogdIbC0cQPyC9xPMZPUGUTSOcXud13KoGlUW9S+SH/Sg7pB0H8HEg+GM/OhMzNI\\na0UJK0HeeacMYm7v9v2IKT1Chw2qrrNToCXCLvZpBdwNbBMHr0KBWG9N+0RayqOt\\nn3PYi8k60vF1k1m3EDLTqAsGNKBTXcCxNwzztu1JgQKBgQDo09qjiYy8T2/ZBjlj\\nMX7MxeOuNMnNQiL+g8FrmtyWs0L7CI7qAYjxh3gtdGRSzCBZuRxQKGF/ViPPtk3n\\nqj2g8049ycwiRvRjoAD6jnz68HvxrFskHMsv84U9yd4zwkNHhbydW6GtMygMqkdq\\nDIkyHeNFw/P2rJHq3UbsMO/CrwKBgQDGyISqqG34dtJEAFFvt5bH1NmOyX5QAFjs\\nHcGP9Vu9uUxnXJ/1fRKvlMLEAtfepU41m+z2C7mKfr/vxURjQB4CAZAFvMcUpnc9\\nBLlwF9Go4PPPoIzxC6kNJEujwPDsBcwAgL9e3nLTrq0eaHi68mXtkg5Oq2g5Q9zM\\ngoDksuYG8wKBgQDGmDaNef1WfrebuYhnyMcsqbscVCCx+TDaQc5RF6YC0WNXtyQY\\nDDkgM/pZY0dTrJQHlDLHWLpZIEOpoAnxii/JQt/BKoj5z+YTuF49Wh7W+Rvvt6GC\\nOyFBhIlpe/AR3CkBL90DqC5PCyylKPWDSrAX1JCQaKWHCgno+NfPDarlNwKBgQC8\\nTcLu7vKNxfFVHYAHdkBNOGKHEnSnUEzsDxwHRQQM63VnDKUypbKHxUHi8FaRwMIf\\non+MbHrsqTkk5xfrdRd4CwbliHiGJVMa6FjJyKaBdedALfSVetg/bLyCeQlAbBVd\\n/JhMRCk+QWAZSBnl7i2EKTGIcHMgnBqTWKTFAHtK5QKBgDGuz6/riH2hqG7V9FOg\\nwOVVCQnaQhmanHcB7V+Q8CTGL2k4WUck5emWal0X9jCYhEWLvPTuCovKsSQQH4ek\\n+Bd3eg1Uj70+BIX+56sW8SRNzdPdFgIymTR1fXdvsabkkzxKFX/ke/CJov++Kt8k\\ncoj35VMt9TXvmp7zH3Sief0D\\n-----END PRIVATE KEY-----\\n\",\r\n  \"client_email\": \"service-account-1@civil-tube-113314.iam.gserviceaccount.com\",\r\n  \"client_id\": \"105732955724324875174\",\r\n  \"auth_uri\": \"https://accounts.google.com/o/oauth2/auth\",\r\n  \"token_uri\": \"https://accounts.google.com/o/oauth2/token\",\r\n  \"auth_provider_x509_cert_url\": \"https://www.googleapis.com/oauth2/v1/certs\",\r\n  \"client_x509_cert_url\": \"https://www.googleapis.com/robot/v1/metadata/x509/service-account-1%40civil-tube-113314.iam.gserviceaccount.com\"\r\n}"
    @ems = FactoryGirl.create(:ems_google, :zone => zone, :provider_region => "us-central1")
    @ems.authentications << FactoryGirl.create(:authentication, :userid => "_", :auth_key => @google_json_key)
    @ems.update_attributes(:project => "civil-tube-113314")

    # A true thread may fail the test with VCR
    allow(Thread).to receive(:new) do |*args, &block|
      block.call(*args)
      Class.new do
        def join; end
      end.new
    end
  end

  it "will perform a full refresh" do
    2.times do # Run twice to verify that a second run with existing data does not change anything
      @ems.reload
      VCR.use_cassette(described_class.name.underscore, :allow_unused_http_interactions => true) do
        EmsRefresh.refresh(@ems)
      end
      @ems.reload

      assert_table_counts
      assert_ems
      assert_specific_zone
      assert_specific_key_pair
      assert_specific_cloud_network
      assert_specific_security_group
      assert_specific_flavor
      assert_specific_vm_powered_on
      assert_specific_vm_powered_off
      assert_specific_template
      assert_specific_cloud_volume
    end
  end

  def assert_table_counts
    expect(ExtManagementSystem.count).to eql(1)
    expect(Flavor.count).to              eql(18)
    expect(AvailabilityZone.count).to    eql(13)
    expect(AuthPrivateKey.count).to      eq(3)
    expect(CloudNetwork.count).to        eql(1)
    expect(SecurityGroup.count).to       eql(1)
    expect(FirewallRule.count).to        eql(6)
    expect(VmOrTemplate.count).to        eql(371)
    expect(Vm.count).to                  eql(2)
    expect(MiqTemplate.count).to         eql(369)
    expect(Disk.count).to                eql(2)
    expect(GuestDevice.count).to         eql(0)
    expect(Hardware.count).to            eql(2)
    expect(Network.count).to             eql(4)
    expect(OperatingSystem.count).to     eql(371)
    expect(Relationship.count).to        eql(4)
    expect(MiqQueue.count).to            eql(371)
    expect(CloudVolume.count).to         eql(4)
  end

  def assert_ems
    expect(@ems.flavors.size).to            eql(18)
    expect(@ems.key_pairs.size).to          eql(3)
    expect(@ems.availability_zones.size).to eql(13)
    expect(@ems.vms_and_templates.size).to  eql(371)
    expect(@ems.cloud_networks.size).to     eql(1)
    expect(@ems.security_groups.size).to    eql(1)
    expect(@ems.vms.size).to                eql(2)
    expect(@ems.miq_templates.size).to      eq(369)
  end

  def assert_specific_zone
    @zone = ManageIQ::Providers::Google::CloudManager::AvailabilityZone.find_by_ems_ref("us-east1-b")
    expect(@zone).to have_attributes(
      :name   => "us-east1-b",
      :ems_id => @ems.id
    )
  end

  def assert_specific_key_pair
    # Find an ssh key added to a single vm
    @kp = ManageIQ::Providers::Google::CloudManager::AuthKeyPair.where(:name => "root").first
    expect(@kp).to have_attributes(
      :name        => "root",
      :fingerprint => "97:c9:58:c8:42:32:3d:e1:47:a9:e6:66:93:51:6a:ae:a9:cb:ee:4a"
    )

    # Find an ssh key added to the whole project
    @project_kp = ManageIQ::Providers::Google::CloudManager::AuthKeyPair.where(:name => "user2").first
    expect(@project_kp).to have_attributes(
      :name        => "user2",
      :fingerprint => "db:46:06:c9:4b:af:d7:18:b4:1d:d0:af:bc:d6:2e:26:48:bc:7d:17"
    )
  end

  def assert_specific_cloud_network
    @cn = CloudNetwork.where(:name => "default").first
    expect(@cn).to have_attributes(
      :name    => "default",
      :ems_ref => "183954628405178359",
      :cidr    => "10.240.0.0/16",
      :status  => "active",
      :enabled => true
    )
  end

  def assert_specific_security_group
    @sg = SecurityGroup.where(:name => "default").first
    expect(@sg).to have_attributes(
      :name    => "default",
      :ems_ref => "default"
    )

    expected_firewall_rules = [
      {
        :name            => "default-allow-icmp",
        :host_protocol   => "ICMP",
        :direction       => "inbound",
        :port            => -1,
        :end_port        => -1,
        :source_ip_range => "0.0.0.0/0"
      },
      {
        :name            => "default-allow-internal",
        :host_protocol   => "ICMP",
        :direction       => "inbound",
        :port            => -1,
        :end_port        => -1,
        :source_ip_range => "10.240.0.0/16"
      },
      {
        :name            => "default-allow-internal",
        :host_protocol   => "TCP",
        :direction       => "inbound",
        :port            => 0,
        :end_port        => 65535,
        :source_ip_range => "10.240.0.0/16"
      },
      {
        :name            => "default-allow-internal",
        :host_protocol   => "UDP",
        :direction       => "inbound",
        :port            => 0,
        :end_port        => 65535,
        :source_ip_range => "10.240.0.0/16"
      },
      {
        :name            => "default-allow-rdp",
        :host_protocol   => "TCP",
        :direction       => "inbound",
        :port            => 3389,
        :end_port        => nil,
        :source_ip_range => "0.0.0.0/0"
      },
      {
        :name            => "default-allow-ssh",
        :host_protocol   => "TCP",
        :direction       => "inbound",
        :port            => 22,
        :end_port        => nil,
        :source_ip_range => "0.0.0.0/0"
      },
    ]

    expect(@sg.firewall_rules.size).to eq(6)

    ordered_fw_rules = @sg.firewall_rules.order(
      :name, :host_protocol, :direction, :port, :end_port, :source_ip_range)

    ordered_fw_rules.zip(expected_firewall_rules).each do |actual, expected|
      expect(actual).to have_attributes(expected)
    end
  end

  def assert_specific_flavor
    @flavor = ManageIQ::Providers::Google::CloudManager::Flavor.where(:name => "f1-micro").first
    expect(@flavor).to have_attributes(
      :name        => "f1-micro",
      :ems_ref     => "f1-micro",
      :description => "1 vCPU (shared physical core) and 0.6 GB RAM",
      :enabled     => true,
      :cpus        => 1,
      :cpu_cores   => 1,
      :memory      => 643825664,
    )

    expect(@flavor.ext_management_system).to eq(@ems)
  end

  def assert_specific_vm_powered_on
    v = ManageIQ::Providers::Google::CloudManager::Vm.where(:name => "rhel7", :raw_power_state => "RUNNING").first
    expect(v).to have_attributes(
      :template              => false,
      :ems_ref               => "5220078748954475260",
      :ems_ref_obj           => nil,
      :uid_ems               => "5220078748954475260",
      :vendor                => "google",
      :power_state           => "on",
      :location              => "unknown",
      :tools_status          => nil,
      :boot_time             => nil,
      :standby_action        => nil,
      :connection_state      => nil,
      :cpu_affinity          => nil,
      :memory_reserve        => nil,
      :memory_reserve_expand => nil,
      :memory_limit          => nil,
      :memory_shares         => nil,
      :memory_shares_level   => nil,
      :cpu_reserve           => nil,
      :cpu_reserve_expand    => nil,
      :cpu_limit             => nil,
      :cpu_shares            => nil,
      :cpu_shares_level      => nil
    )

    expect(v.ext_management_system).to         eql(@ems)
    expect(v.availability_zone).to             eql(@zone)
    expect(v.flavor).to                        eql(@flavor)
    expect(v.operating_system.product_name).to eql("linux_redhat")
    expect(v.custom_attributes.size).to        eql(0)
    expect(v.snapshots.size).to                eql(0)

    assert_specific_vm_powered_on_hardware(v)
  end

  def assert_specific_vm_powered_on_hardware(v)
    expect(v.hardware).to have_attributes(
      :guest_os            => nil,
      :guest_os_full_name  => nil,
      :bios                => nil,
      :annotation          => nil,
      :cpu_sockets         => 1,
      :memory_mb           => 614,
      :bitness             => nil,
      :virtualization_type => nil
    )

    expect(v.hardware.guest_devices.size).to eql(0)
    expect(v.hardware.nics.size).to          eql(0)

    assert_specific_vm_powered_on_hardware_networks(v)
    assert_specific_vm_powered_on_hardware_disks(v)
  end

  def assert_specific_vm_powered_on_hardware_networks(v)
    expect(v.hardware.networks.size).to eql(2)

    network = v.hardware.networks.where(:description => "default private").first
    expect(network).to have_attributes(
      :description => "default private",
      :ipaddress   => "10.240.0.2",
      :hostname    => nil
    )

    network = v.hardware.networks.where(:description => "default External NAT").first
    expect(network).to have_attributes(
      :description => "default External NAT",
      :ipaddress   => "104.196.37.81",
      :hostname    => nil
    )
  end

  def assert_specific_vm_powered_on_hardware_disks(v)
    expect(v.hardware.disks.size).to eql(1)

    disk = v.hardware.disks.first
    expect(disk).to have_attributes(
      :device_name     => "rhel7",
      :device_type     => "disk",
      :location        => "0",
      :controller_type => "google",
      :size            => 10.gigabyte,
      :backing_type    => "CloudVolume"
    )
    expect(disk.backing).to eql(CloudVolume.where(:name => "rhel7").first)
  end

  def assert_specific_cloud_volume
    v = CloudVolume.where(
      :name            => "rhel7"
    ).first

    expect(v.ems_ref).to                 eql("7616431006268085360")
    expect(v.name).to                    eql("rhel7")
    expect(v.status).to                  eql("READY")
    expect(v.creation_time.to_s).to      eql("2015-11-18 21:16:15 UTC")
    expect(v.volume_type).to             eql("pd-standard")
    expect(v.description).to             eql(nil)
    expect(v.size).to                    eql(10.gigabyte)
    expect(v.availability_zone.name).to  eql("us-east1-b")
  end

  def assert_specific_vm_powered_off
    v = ManageIQ::Providers::Google::CloudManager::Vm.where(
      :name            => "wheezy",
      :raw_power_state => "TERMINATED").first

    zone1 = ManageIQ::Providers::Google::CloudManager::AvailabilityZone.where(:name => "us-central1-b").first

    assert_specific_vm_powered_off_attributes(v)

    expect(v.ext_management_system).to  eql(@ems)
    expect(v.availability_zone).to      eql(zone1)
    expect(v.floating_ip).to            be_nil
    expect(v.cloud_network).to          eql(@cn)
    expect(v.cloud_subnet).to           be_nil
    #TODO parse instance OS v.operating_system.product_name.should eql("Debian")

    # This should have keys added on just this vm (@kp) as well as
    # on the whole project (@project_kp)
    expect(v.key_pairs.to_a).to         eql([@kp, @project_kp])
    expect(v.custom_attributes.size).to eql(0)
    expect(v.snapshots.size).to         eql(0)

    assert_specific_vm_powered_off_hardware(v)
  end

  def assert_specific_vm_powered_off_attributes(v)
    expect(v).to have_attributes(
      :template              => false,
      :ems_ref               => "17122958274615180727",
      :ems_ref_obj           => nil,
      :uid_ems               => "17122958274615180727",
      :vendor                => "google",
      :power_state           => "off",
      :location              => "unknown",
      :tools_status          => nil,
      :boot_time             => nil,
      :standby_action        => nil,
      :connection_state      => nil,
      :cpu_affinity          => nil,
      :memory_reserve        => nil,
      :memory_reserve_expand => nil,
      :memory_limit          => nil,
      :memory_shares         => nil,
      :memory_shares_level   => nil,
      :cpu_reserve           => nil,
      :cpu_reserve_expand    => nil,
      :cpu_limit             => nil,
      :cpu_shares            => nil,
      :cpu_shares_level      => nil
    )
  end

  def assert_specific_vm_powered_off_hardware(v)
    expect(v.hardware).to have_attributes(
      :guest_os           => nil,
      :guest_os_full_name => nil,
      :bios               => nil,
      :annotation         => nil,
      :cpu_sockets        => 1,
      :memory_mb          => 614,
      :bitness            => nil
    )

    expect(v.hardware.disks.size).to         eql(1)
    expect(v.hardware.guest_devices.size).to eql(0)
    expect(v.hardware.nics.size).to          eql(0)
    expect(v.hardware.networks.size).to      eql(2)
  end

  def assert_specific_template
    name      = "rhel-7-v20151104"
    @template = ManageIQ::Providers::Google::CloudManager::Template.where(:name => name).first
    expect(@template).to have_attributes(
      :template              => true,
      :ems_ref               => "5670907071397924697",
      :ems_ref_obj           => nil,
      :uid_ems               => "5670907071397924697",
      :vendor                => "google",
      :power_state           => "never",
      :location              => "unknown",
      :tools_status          => nil,
      :boot_time             => nil,
      :standby_action        => nil,
      :connection_state      => nil,
      :cpu_affinity          => nil,
      :memory_reserve        => nil,
      :memory_reserve_expand => nil,
      :memory_limit          => nil,
      :memory_shares         => nil,
      :memory_shares_level   => nil,
      :cpu_reserve           => nil,
      :cpu_reserve_expand    => nil,
      :cpu_limit             => nil,
      :cpu_shares            => nil,
      :cpu_shares_level      => nil
    )

    expect(@template.ext_management_system).to         eq(@ems)
    expect(@template.operating_system.product_name).to eq("linux_redhat")
    expect(@template.custom_attributes.size).to        eq(0)
    expect(@template.snapshots.size).to                eq(0)
  end
end
