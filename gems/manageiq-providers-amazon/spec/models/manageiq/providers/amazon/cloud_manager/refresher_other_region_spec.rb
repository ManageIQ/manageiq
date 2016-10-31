describe ManageIQ::Providers::Amazon::CloudManager::Refresher do
  before(:each) do
    guid, server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_amazon, :provider_region => "us-west-1", :zone => zone)
    @ems.update_authentication(:default => {
                                 :userid   => "0123456789ABCDEFGHIJ",
                                 :password => "ABCDEFGHIJKLMNO1234567890abcdefghijklmno"
                               })
  end

  it "will perform a full refresh on another region" do
    2.times do  # Run twice to verify that a second run with existing data does not change anything
      @ems.reload

      VCR.use_cassette("#{described_class.name.underscore}_other_region") do
        EmsRefresh.refresh(@ems)
        EmsRefresh.refresh(@ems.network_manager)
      end
      @ems.reload

      assert_table_counts
      assert_ems
      assert_specific_flavor
      assert_specific_az
      assert_specific_floating_ip
      assert_specific_key_pair
      assert_specific_security_group
      assert_specific_template
      assert_specific_vm_powered_on
      assert_specific_vm_in_other_region
      assert_relationship_tree
      assert_subnet_required
    end
  end

  def assert_table_counts
    expect(ExtManagementSystem.count).to eq(2)
    expect(Flavor.count).to eq(56)
    expect(AvailabilityZone.count).to eq(3)
    expect(FloatingIp.count).to eq(3)
    expect(AuthPrivateKey.count).to eq(2)
    expect(SecurityGroup.count).to eq(2)
    expect(FirewallRule.count).to eq(4)
    expect(VmOrTemplate.count).to eq(3)
    expect(Vm.count).to eq(2)
    expect(MiqTemplate.count).to eq(1)

    expect(CustomAttribute.count).to eq(0)
    expect(Disk.count).to eq(1)
    expect(GuestDevice.count).to eq(0)
    expect(Hardware.count).to eq(3)
    expect(Network.count).to eq(4)
    expect(OperatingSystem.count).to eq(0) # TODO: Should this be 15 (set on all vms)?
    expect(Snapshot.count).to eq(0)
    expect(SystemService.count).to eq(0)

    expect(Relationship.count).to eq(2)
    expect(MiqQueue.count).to eq(6)
  end

  def assert_ems
    expect(@ems).to have_attributes(
      :api_version => nil, # TODO: Should be 3.0
      :uid_ems     => nil
    )

    expect(@ems.flavors.size).to eq(56)
    expect(@ems.availability_zones.size).to eq(3)
    expect(@ems.floating_ips.size).to eq(3)
    expect(@ems.key_pairs.size).to eq(2)
    expect(@ems.security_groups.size).to eq(2)
    expect(@ems.vms_and_templates.size).to eq(3)
    expect(@ems.vms.size).to eq(2)
    expect(@ems.miq_templates.size).to eq(1)
  end

  def assert_specific_flavor
    @flavor = ManageIQ::Providers::Amazon::CloudManager::Flavor.where(:name => "t1.micro").first
    expect(@flavor).to have_attributes(
      :name                 => "t1.micro",
      :description          => "T1 Micro",
      :enabled              => true,
      :cpus                 => 1,
      :cpu_cores            => 1,
      :memory               => 613.megabytes.to_i,
      :supports_32_bit      => true,
      :supports_64_bit      => true,
      :supports_hvm         => false,
      :supports_paravirtual => true
    )

    expect(@flavor.ext_management_system).to eq(@ems)
  end

  def assert_specific_az
    @az = ManageIQ::Providers::Amazon::CloudManager::AvailabilityZone.where(:name => "us-west-1a").first
    expect(@az).to have_attributes(
      :name => "us-west-1a",
    )
  end

  def assert_specific_floating_ip
    ip = ManageIQ::Providers::Amazon::NetworkManager::FloatingIp.where(:address => "54.215.0.230").first
    expect(ip).to have_attributes(
      :address            => "54.215.0.230",
      :ems_ref            => "54.215.0.230",
      :cloud_network_only => false
    )

    @ip = ManageIQ::Providers::Amazon::NetworkManager::FloatingIp.where(:address => "204.236.137.154").first
    expect(@ip).to have_attributes(
      :address            => "204.236.137.154",
      :ems_ref            => "204.236.137.154",
      :fixed_ip_address   => "10.191.129.95",
      :cloud_network_only => false
    )
  end

  def assert_specific_key_pair
    @kp = ManageIQ::Providers::Amazon::CloudManager::AuthKeyPair.where(:name => "EmsRefreshSpec-KeyPair-OtherRegion").first
    expect(@kp).to have_attributes(
      :name        => "EmsRefreshSpec-KeyPair-OtherRegion",
      :fingerprint => "fc:53:30:aa:d2:23:c7:8d:e2:e8:05:95:a0:d2:90:fb:15:30:a2:51"
    )
  end

  def assert_specific_security_group
    @sg = ManageIQ::Providers::Amazon::NetworkManager::SecurityGroup.where(:name => "EmsRefreshSpec-SecurityGroup-OtherRegion").first
    expect(@sg).to have_attributes(
      :name        => "EmsRefreshSpec-SecurityGroup-OtherRegion",
      :description => "EmsRefreshSpec-SecurityGroup-OtherRegion",
      :ems_ref     => "sg-2b87746f"
    )

    expect(@sg.firewall_rules.size).to eq(1)
    expect(@sg.firewall_rules.first).to have_attributes(
      :host_protocol            => "TCP",
      :direction                => "inbound",
      :port                     => 0,
      :end_port                 => 65535,
      :source_security_group_id => nil,
      :source_ip_range          => "0.0.0.0/0"
    )
  end

  def assert_specific_template
    @template = ManageIQ::Providers::Amazon::CloudManager::Template.where(:name => "EmsRefreshSpec-Image-OtherRegion").first
    expect(@template).to have_attributes(
      :template              => true,
      :ems_ref               => "ami-183e175d",
      :ems_ref_obj           => nil,
      :uid_ems               => "ami-183e175d",
      :vendor                => "amazon",
      :power_state           => "never",
      :location              => "200278856672/EmsRefreshSpec-Image-OtherRegion",
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

    expect(@template.ext_management_system).to eq(@ems)
    expect(@template.operating_system).to       be_nil # TODO: This should probably not be nil
    expect(@template.custom_attributes.size).to eq(0)
    expect(@template.snapshots.size).to eq(0)

    expect(@template.hardware).to have_attributes(
      :guest_os           => "linux",
      :guest_os_full_name => nil,
      :bios               => nil,
      :annotation         => nil,
      :cpu_sockets        => 1, # wtf
      :memory_mb          => nil,
      :disk_capacity      => nil,
      :bitness            => 64
    )

    expect(@template.hardware.disks.size).to eq(0)
    expect(@template.hardware.guest_devices.size).to eq(0)
    expect(@template.hardware.nics.size).to eq(0)
    expect(@template.hardware.networks.size).to eq(0)
  end

  def assert_specific_vm_powered_on
    v = ManageIQ::Providers::Amazon::CloudManager::Vm.where(:name => "EmsRefreshSpec-PoweredOn-OtherRegion", :raw_power_state => "running").first
    expect(v).to have_attributes(
      :template              => false,
      :ems_ref               => "i-dc1ee486",
      :ems_ref_obj           => nil,
      :uid_ems               => "i-dc1ee486",
      :vendor                => "amazon",
      :power_state           => "on",
      :location              => "ec2-204-236-137-154.us-west-1.compute.amazonaws.com",
      :tools_status          => nil,
      :boot_time             => "2013-08-31T00:12:43.000",
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
    expect(v.availability_zone).to eq(@az)
    expect(v.floating_ip).to eq(@ip)
    expect(v.flavor).to eq(@flavor)
    expect(v.cloud_network).to          be_nil
    expect(v.cloud_subnet).to           be_nil
    expect(v.security_groups).to eq([@sg])
    expect(v.key_pairs).to eq([@kp])
    expect(v.operating_system).to       be_nil # TODO: This should probably not be nil
    expect(v.custom_attributes.size).to eq(0)
    expect(v.snapshots.size).to eq(0)

    expect(v.hardware).to have_attributes(
      :guest_os           => "linux",
      :guest_os_full_name => nil,
      :bios               => nil,
      :annotation         => nil,
      :cpu_sockets        => 1,
      :memory_mb          => 613,
      :disk_capacity      => 0, # TODO: Change to a flavor that has disks
      :bitness            => 64
    )

    expect(v.hardware.disks.size).to eq(0) # TODO: Change to a flavor that has disks
    expect(v.hardware.guest_devices.size).to eq(0)
    expect(v.hardware.nics.size).to eq(0)

    expect(v.hardware.networks.size).to eq(2)
    network = v.hardware.networks.where(:description => "public").first
    expect(network).to have_attributes(
      :description => "public",
      :ipaddress   => "204.236.137.154",
      :hostname    => "ec2-204-236-137-154.us-west-1.compute.amazonaws.com"
    )
    network = v.hardware.networks.where(:description => "private").first
    expect(network).to have_attributes(
      :description => "private",
      :ipaddress   => "10.191.129.95",
      :hostname    => "ip-10-191-129-95.us-west-1.compute.internal"
    )

    v.with_relationship_type("genealogy") do
      expect(v.parent).to eq(@template)
    end
  end

  def assert_specific_vm_in_other_region
    v = ManageIQ::Providers::Amazon::CloudManager::Vm.where(:name => "EmsRefreshSpec-PoweredOn-Basic").first
    expect(v).to be_nil
  end

  def assert_relationship_tree
    expect(@ems.descendants_arranged).to match_relationship_tree({})
  end

  def assert_subnet_required
    @flavor = ManageIQ::Providers::Amazon::CloudManager::Flavor.where(:name => "t2.small").first
    expect(@flavor).to have_attributes(:cloud_subnet_required => true)
  end
end
