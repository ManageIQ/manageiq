require "spec_helper"
require 'fog/google'

describe ManageIQ::Providers::Google::CloudManager::Refresher do
  before(:each) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @google_json_key = "{\r\n  \"type\": \"service_account\",\r\n  \"project_id\": \"civil-tube-113314\",\r\n  \"private_key_id\": \"b30f7f40eb725006e658bc5bd2f58200df81280a\",\r\n  \"private_key\": \"-----BEGIN PRIVATE KEY-----\\nMIIEvgIBADANBgkqhkiG9w0BAQEFAASCBKgwggSkAgEAAoIBAQC0yjlFvsDexy22\\nAdXET0ptuS1r091fQn3RREbmZsbLvlxiRfdySJpnkOv8fmzoz7/1q1vxGhnftA9S\\nPyxCz1WSc/JDac8iybh5/zg96oFk9rq6VVc7lGy/i9igrxQzyzkPIuS0g0Y1OzRz\\nRro+AKBLgKcejd6EZ16jJWYRgAtD4c2CWizYCFNfHJzn/e8mBWGWYdmqr6VxaXNf\\nBesL+aF/FimAvCEwW1zbXZEkq6vMzlNdUO3EvpDr+yfHdjre+KcflrxVdr6Ju9QD\\nHlAENgP78cZNL1Gk4Os1wSMf8GQV4yKRO/wAGJI4KS4Id8iijwjWhDHCJgdfPNmt\\na/qpX+YdAgMBAAECggEAASXHd0ner4tUHvOkB7r5Hfku8KBHp3MkmU91o8DDQkfT\\nDkyjZXZQhJfG57NlvZSUA1szGjSwNVtPPZZpEYN/Z46U2xiw1+ev5BZapQn4CEwI\\no2YnR5mJly2sElkKJ8oCcrYl/X9X0r6tdo3cYMhgPBp09RyxbOW7FA4It9O4PpYN\\nmogdIbC0cQPyC9xPMZPUGUTSOcXud13KoGlUW9S+SH/Sg7pB0H8HEg+GM/OhMzNI\\na0UJK0HeeacMYm7v9v2IKT1Chw2qrrNToCXCLvZpBdwNbBMHr0KBWG9N+0RayqOt\\nn3PYi8k60vF1k1m3EDLTqAsGNKBTXcCxNwzztu1JgQKBgQDo09qjiYy8T2/ZBjlj\\nMX7MxeOuNMnNQiL+g8FrmtyWs0L7CI7qAYjxh3gtdGRSzCBZuRxQKGF/ViPPtk3n\\nqj2g8049ycwiRvRjoAD6jnz68HvxrFskHMsv84U9yd4zwkNHhbydW6GtMygMqkdq\\nDIkyHeNFw/P2rJHq3UbsMO/CrwKBgQDGyISqqG34dtJEAFFvt5bH1NmOyX5QAFjs\\nHcGP9Vu9uUxnXJ/1fRKvlMLEAtfepU41m+z2C7mKfr/vxURjQB4CAZAFvMcUpnc9\\nBLlwF9Go4PPPoIzxC6kNJEujwPDsBcwAgL9e3nLTrq0eaHi68mXtkg5Oq2g5Q9zM\\ngoDksuYG8wKBgQDGmDaNef1WfrebuYhnyMcsqbscVCCx+TDaQc5RF6YC0WNXtyQY\\nDDkgM/pZY0dTrJQHlDLHWLpZIEOpoAnxii/JQt/BKoj5z+YTuF49Wh7W+Rvvt6GC\\nOyFBhIlpe/AR3CkBL90DqC5PCyylKPWDSrAX1JCQaKWHCgno+NfPDarlNwKBgQC8\\nTcLu7vKNxfFVHYAHdkBNOGKHEnSnUEzsDxwHRQQM63VnDKUypbKHxUHi8FaRwMIf\\non+MbHrsqTkk5xfrdRd4CwbliHiGJVMa6FjJyKaBdedALfSVetg/bLyCeQlAbBVd\\n/JhMRCk+QWAZSBnl7i2EKTGIcHMgnBqTWKTFAHtK5QKBgDGuz6/riH2hqG7V9FOg\\nwOVVCQnaQhmanHcB7V+Q8CTGL2k4WUck5emWal0X9jCYhEWLvPTuCovKsSQQH4ek\\n+Bd3eg1Uj70+BIX+56sW8SRNzdPdFgIymTR1fXdvsabkkzxKFX/ke/CJov++Kt8k\\ncoj35VMt9TXvmp7zH3Sief0D\\n-----END PRIVATE KEY-----\\n\",\r\n  \"client_email\": \"service-account-1@civil-tube-113314.iam.gserviceaccount.com\",\r\n  \"client_id\": \"105732955724324875174\",\r\n  \"auth_uri\": \"https://accounts.google.com/o/oauth2/auth\",\r\n  \"token_uri\": \"https://accounts.google.com/o/oauth2/token\",\r\n  \"auth_provider_x509_cert_url\": \"https://www.googleapis.com/oauth2/v1/certs\",\r\n  \"client_x509_cert_url\": \"https://www.googleapis.com/robot/v1/metadata/x509/service-account-1%40civil-tube-113314.iam.gserviceaccount.com\"\r\n}"
    @ems = FactoryGirl.create(:ems_google, :zone => zone, :provider_region => "us-central1")
    @ems.authentications << FactoryGirl.create(:authentication, :userid => "_", :auth_key => @google_json_key)
    @ems.update_attributes(:project => "civil-tube-113314")

    # A true thread may fail the test with VCR
    Thread.stub(:new) do |*args, &block|
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
      assert_specific_cloud_network
      assert_specific_flavor
      assert_specific_vm_powered_on
      assert_specific_vm_powered_off
      assert_specific_template
    end
  end

  def assert_table_counts
    ExtManagementSystem.count.should eql(1)
    Flavor.count.should              eql(18)
    AvailabilityZone.count.should    eql(13)
    VmOrTemplate.count.should        eql(347)
    Vm.count.should                  eql(2)
    MiqTemplate.count.should         eql(345)
    Disk.count.should                eql(0)
    GuestDevice.count.should         eql(0)
    Hardware.count.should            eql(2)
    Network.count.should             eql(0)
    OperatingSystem.count.should     eql(345)
    Relationship.count.should        eql(0)
    MiqQueue.count.should            eql(347)
  end

  def assert_ems
    @ems.flavors.size.should            eql(18)
    @ems.availability_zones.size.should eql(13)
    @ems.vms_and_templates.size.should  eql(347)
    @ems.vms.size.should                eql(2)
    @ems.miq_templates.size.should      eq(345)
  end

  def assert_specific_zone
    @zone = ManageIQ::Providers::Google::CloudManager::AvailabilityZone.find_by_ems_ref("us-east1-b")
    @zone.should have_attributes(
      :name   => "us-east1-b",
      :ems_id => @ems.id
    )
  end

  def assert_specific_cloud_network
    @cn = CloudNetwork.where(:name => "default").first
    @cn.should have_attributes(
      :name    => "default",
      :ems_ref => "183954628405178359",
      :cidr    => "10.240.0.0/16",
      :status  => "active",
      :enabled => true
    )
  end

  def assert_specific_flavor
    @flavor = ManageIQ::Providers::Google::CloudManager::Flavor.where(:name => "f1-micro").first
    @flavor.should have_attributes(
      :name        => "f1-micro",
      :ems_ref     => "f1-micro",
      :description => "1 vCPU (shared physical core) and 0.6 GB RAM",
      :enabled     => true,
      :cpus        => 1,
      :cpu_cores   => 1,
      :memory      => 643825664,
    )

    @flavor.ext_management_system.should == @ems
  end

  def assert_specific_vm_powered_on
    v = ManageIQ::Providers::Google::CloudManager::Vm.where(:name => "rhel7", :raw_power_state => "RUNNING").first
    v.should have_attributes(
      :template              => false,
      :ems_ref               => "5220078748954475260",
      :ems_ref_obj           => nil,
      :uid_ems               => "5220078748954475260",
      :vendor                => "Google",
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

    v.ext_management_system.should eql(@ems)
    v.availability_zone.should eql(@zone)
    #TODO parse instance flavor v.flavor.should eql(@flavor)
    #TODO parse instance OS v.operating_system.product_name.should eql("Red Hat Enterprise Linux")
    v.custom_attributes.size.should eql(0)
    v.snapshots.size.should         eql(0)

    assert_specific_vm_powered_on_hardware(v)
  end

  def assert_specific_vm_powered_on_hardware(v)
    v.hardware.should have_attributes(
      :guest_os            => nil,
      :guest_os_full_name  => nil,
      :bios                => nil,
      :annotation          => nil,
      :cpu_sockets         => 1,
      :memory_mb           => 614,
      :bitness             => nil,
      :virtualization_type => nil
    )

    v.hardware.disks.size.should         eql(0) # TODO: Change to a flavor that has disks
    v.hardware.guest_devices.size.should eql(0)
    v.hardware.nics.size.should          eql(0)

    assert_specific_vm_powered_on_hardware_networks(v)
  end

  def assert_specific_vm_powered_on_hardware_networks(v)
    v.hardware.networks.size.should eql(0)
    # TODO inventory network hardware
  end

  def assert_specific_vm_powered_off
    v = ManageIQ::Providers::Google::CloudManager::Vm.where(
      :name            => "wheezy",
      :raw_power_state => "TERMINATED").first

    zone1 = ManageIQ::Providers::Google::CloudManager::AvailabilityZone.where(:name => "us-central1-b").first

    assert_specific_vm_powered_off_attributes(v)

    v.ext_management_system.should  eql(@ems)
    v.availability_zone.should      eql(zone1)
    v.floating_ip.should            be_nil
    v.cloud_network.should          be_nil
    v.cloud_subnet.should           be_nil
    #TODO parse instance OS v.operating_system.product_name.should eql("Debian")
    v.custom_attributes.size.should eql(0)
    v.snapshots.size.should         eql(0)

    assert_specific_vm_powered_off_hardware(v)
  end

  def assert_specific_vm_powered_off_attributes(v)
    v.should have_attributes(
      :template              => false,
      :ems_ref               => "17122958274615180727",
      :ems_ref_obj           => nil,
      :uid_ems               => "17122958274615180727",
      :vendor                => "Google",
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
    v.hardware.should have_attributes(
      :guest_os           => nil,
      :guest_os_full_name => nil,
      :bios               => nil,
      :annotation         => nil,
      :cpu_sockets        => 1,
      :memory_mb          => 614,
      :bitness            => nil
    )

    v.hardware.disks.size.should         eql(0)
    v.hardware.guest_devices.size.should eql(0)
    v.hardware.nics.size.should          eql(0)
    v.hardware.networks.size.should      eql(0)
  end

  def assert_specific_template
    name      = "rhel-7-v20151104"
    @template = ManageIQ::Providers::Google::CloudManager::Template.where(:name => name).first
    @template.should have_attributes(
      :template              => true,
      :ems_ref               => "5670907071397924697",
      :ems_ref_obj           => nil,
      :uid_ems               => "5670907071397924697",
      :vendor                => "Google",
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

    @template.ext_management_system.should         eq(@ems)
    @template.operating_system.product_name.should eq("linux_redhat")
    @template.custom_attributes.size.should        eq(0)
    @template.snapshots.size.should                eq(0)
  end
end
