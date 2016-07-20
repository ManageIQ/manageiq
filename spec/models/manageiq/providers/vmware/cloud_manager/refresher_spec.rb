describe ManageIQ::Providers::Vmware::CloudManager::Refresher do
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
    expect(described_class.ems_type).to eq(:vmware_cloud)
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
      assert_specific_vm_powered_on
      assert_specific_vm_powered_off
    end
  end

  def assert_table_counts
    expect(ExtManagementSystem.count).to eq(1)
    expect(Flavor.count).to eq(0)
    expect(AvailabilityZone.count).to eq(0)
    expect(FloatingIp.count).to eq(0)
    expect(AuthPrivateKey.count).to eq(0)
    expect(CloudNetwork.count).to eq(0)
    expect(CloudSubnet.count).to eq(0)
    expect(OrchestrationTemplate.count).to eq(0)
    expect(OrchestrationStack.count).to eq(0)
    expect(OrchestrationStackParameter.count).to eq(0)
    expect(OrchestrationStackOutput.count).to eq(0)
    expect(OrchestrationStackResource.count).to eq(0)
    expect(SecurityGroup.count).to eq(0)
    expect(FirewallRule.count).to eq(0)
    expect(VmOrTemplate.count).to eq(6)
    expect(Vm.count).to eq(6)
    expect(MiqTemplate.count).to eq(0)

    expect(CustomAttribute.count).to eq(0)
    expect(Disk.count).to eq(8)
    expect(GuestDevice.count).to eq(0)
    expect(Hardware.count).to eq(6)
    expect(OperatingSystem.count).to eq(6)
    expect(Snapshot.count).to eq(0)
    expect(SystemService.count).to eq(0)

    expect(Relationship.count).to eq(0)
    expect(MiqQueue.count).to eq(6)
  end

  def assert_ems
    expect(@ems).to have_attributes(
      :api_version => "5.1",
      :uid_ems     => nil
    )

    expect(@ems.flavors.size).to eq(0)
    expect(@ems.availability_zones.size).to eq(0)
    expect(@ems.floating_ips.size).to eq(0)
    expect(@ems.key_pairs.size).to eq(0)
    expect(@ems.cloud_networks.size).to eq(0)
    expect(@ems.security_groups.size).to eq(0)
    expect(@ems.vms_and_templates.size).to eq(6)
    expect(@ems.vms.size).to eq(6)
    expect(@ems.miq_templates.size).to eq(0)
    expect(@ems.orchestration_stacks.size).to eq(0)

    expect(@ems.direct_orchestration_stacks.size).to eq(0)
  end

  def assert_specific_vm_powered_on
    v = ManageIQ::Providers::Vmware::CloudManager::Vm.where(
      :name            => "login").first
    expect(v).to have_attributes(
      :template              => false,
      :ems_ref               => "vm-fb442a57-921c-496f-ba6d-1b7e29459bb2",
      :ems_ref_obj           => nil,
      :uid_ems               => "vm-fb442a57-921c-496f-ba6d-1b7e29459bb2",
      :vendor                => "vmware",
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

    expect(v.ext_management_system).to eq(@ems)
    expect(v.availability_zone).to be_nil
    expect(v.floating_ip).to be_nil
    expect(v.key_pairs.size).to eq(0)
    expect(v.cloud_network).to be_nil
    expect(v.cloud_subnet).to be_nil
    expect(v.security_groups.size).to eq(0)

    expect(v.operating_system).to have_attributes(
      :product_name => "CentOS 4/5/6/7 (64-bit)",
    )
    expect(v.custom_attributes.size).to eq(0)
    expect(v.snapshots.size).to eq(0)

    expect(v.hardware).to have_attributes(
      :config_version       => nil,
      :virtual_hw_version   => nil,
      :guest_os             => "CentOS 4/5/6/7 (64-bit)",
      :guest_os_full_name   => "CentOS 4/5/6/7 (64-bit)",
      :cpu_sockets          => 1,
      :bios                 => nil,
      :bios_location        => nil,
      :time_sync            => nil,
      :annotation           => nil,
      :memory_mb            => 512,
      :host_id              => nil,
      :cpu_speed            => nil,
      :cpu_type             => nil,
      :size_on_disk         => nil,
      :manufacturer         => "",
      :model                => "",
      :number_of_nics       => nil,
      :cpu_usage            => nil,
      :memory_usage         => nil,
      :cpu_cores_per_socket => 1,
      :cpu_total_cores      => 1,
      :vmotion_enabled      => nil,
      :disk_free_space      => nil,
      :disk_capacity        => 17_179_869_184,
      :memory_console       => nil,
      :bitness              => 64,
      :virtualization_type  => nil,
      :root_device_type     => nil,
    )

    expect(v.hardware.disks.size).to eq(1)
    expect(v.hardware.disks.first).to have_attributes(
      :device_name     => "Hard disk 1",
      :device_type     => "disk",
      :controller_type => "SCSI Controller",
      :size            => 17_179_869_184,
    )
    expect(v.hardware.guest_devices.size).to eq(0)
    expect(v.hardware.nics.size).to eq(0)
  end

  def assert_specific_vm_powered_off
    v = ManageIQ::Providers::Vmware::CloudManager::Vm.where(
      :name            => "testvm").first
    expect(v).to have_attributes(
      :template              => false,
      :ems_ref               => "vm-68745fa5-2a44-4ca5-95dc-c265758b420e",
      :ems_ref_obj           => nil,
      :uid_ems               => "vm-68745fa5-2a44-4ca5-95dc-c265758b420e",
      :vendor                => "vmware",
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

    expect(v.ext_management_system).to eq(@ems)
    expect(v.availability_zone).to be_nil
    expect(v.floating_ip).to be_nil
    expect(v.key_pairs.size).to eq(0)
    expect(v.cloud_network).to be_nil
    expect(v.cloud_subnet).to be_nil
    expect(v.security_groups.size).to eq(0)

    expect(v.operating_system).to have_attributes(
      :product_name => "Ubuntu Linux (64-bit)",
    )

    expect(v.custom_attributes.size).to eq(0)
    expect(v.snapshots.size).to eq(0)

    expect(v.hardware).to have_attributes(
      :config_version       => nil,
      :virtual_hw_version   => nil,
      :guest_os             => "Ubuntu Linux (64-bit)",
      :guest_os_full_name   => "Ubuntu Linux (64-bit)",
      :cpu_sockets          => 1,
      :bios                 => nil,
      :bios_location        => nil,
      :time_sync            => nil,
      :annotation           => nil,
      :memory_mb            => 512,
      :host_id              => nil,
      :cpu_speed            => nil,
      :cpu_type             => nil,
      :size_on_disk         => nil,
      :manufacturer         => "",
      :model                => "",
      :number_of_nics       => nil,
      :cpu_usage            => nil,
      :memory_usage         => nil,
      :cpu_cores_per_socket => 1,
      :cpu_total_cores      => 1,
      :vmotion_enabled      => nil,
      :disk_free_space      => nil,
      :disk_capacity        => 17_179_869_184,
      :memory_console       => nil,
      :bitness              => 64,
      :virtualization_type  => nil,
      :root_device_type     => nil,
    )

    expect(v.hardware.disks.size).to eq(1)
    expect(v.hardware.disks.first).to have_attributes(
      :device_name     => "Hard disk 1",
      :device_type     => "disk",
      :controller_type => "SCSI Controller",
      :size            => 17_179_869_184,
    )
    expect(v.hardware.guest_devices.size).to eq(0)
    expect(v.hardware.nics.size).to eq(0)
  end
end
