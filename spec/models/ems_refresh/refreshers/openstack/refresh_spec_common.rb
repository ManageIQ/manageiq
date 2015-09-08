require 'tools/environment_builders/openstack/services/compute/data'
require 'tools/environment_builders/openstack/services/identity/data'
require 'tools/environment_builders/openstack/services/image/data'
require 'tools/environment_builders/openstack/services/network/data/neutron'
require 'tools/environment_builders/openstack/services/network/data/nova'
require 'tools/environment_builders/openstack/services/volume/data'

require_relative 'refresh_spec_environments'
require_relative 'refresh_spec_helpers'
require_relative 'refresh_spec_matchers'

module Openstack
  module RefreshSpecCommon
    def self.included(klass)
      klass.class_eval do
        include RefreshSpecEnvironments
        include RefreshSpecHelpers
        include RefreshSpecMatchers
      end
    end

    def assert_with_skips
      # skips configured modules
      expect(CloudVolume.count).to eq 0

      # .. but other things are still present:
      expect(Disk.count).to       eq vms_count * 3
      expect(FloatingIp.count).to eq network_data.floating_ips.sum
    end

    def assert_common
      assert_ems
      assert_specific_flavor
      assert_specific_az
      assert_availability_zone_null
      assert_specific_tenant
      assert_key_pairs
      assert_specific_security_groups
      assert_specific_network
      assert_specific_templates
      assert_specific_vms
      assert_relationship_tree

      # Assert table counts as last, just for sure. First we compare Hashes of data, so we see the diffs
      assert_table_counts
    end

    def volumes_count
      # We create snapshots from all servers in the enviroment builder, take the ones that had volume associated and
      # compute how many servers was created using that snapshots. Volumes attached there, will be also snapshoted and
      # then created and attached to each server, created by such snapshot.
      servers_with_volumes_names = compute_data.servers.select do |x|
        !x[:__block_device_name].blank?
      end
      servers_with_volumes_names = servers_with_volumes_names.map { |x| x[:name] }

      snapshots_with_volumes_names = servers_with_volumes_names.map do |x|
        image_data.servers_snapshots(x)
      end
      snapshots_with_volumes_names = snapshots_with_volumes_names.compact.flatten.map { |x| x[:name] }

      servers_created_by_snapshots_with_volumes = compute_data.servers_from_snapshot.select do |x|
        snapshots_with_volumes_names.include?(x[:__image_name])
      end

      # Volumes count + volumes created from snapshots + volumes created by snapshoting and recreating vm that had
      # volume attached
      (volume_data.volumes.count + volume_data.volumes_from_snapshots.count +
       servers_created_by_snapshots_with_volumes.count)
    end

    def firewall_rules_count
      # Number of defined rules
      count = network_data.security_group_rules.count
      # Neutron puts there + 4 default rules for each default security group + 2 empty default rules for each security
      # group created
      count += default_security_groups_count * 4 + network_data.security_groups.count * 2 if neutron_networking?
      count
    end

    def default_security_groups_count
      # There is default security group per each tenant
      count = identity_data.projects.count
      # Neutron puts there one extra security group, that is noit assosiated to any tenant
      count += 1 if neutron_networking?
      count
    end

    def security_groups_count
      # Number of defined security groups + default group per each project, that is created automatically
      network_data.security_groups.count + default_security_groups_count
    end

    def images_count
      # Images + snaphosts + 2 AKI and ARI images not specified in data specs
      image_data.images.count + image_data.servers_snapshots.count + 2
    end

    def vms_count
      # VMs + Vms created from snapshots
      compute_data.servers.count + compute_data.servers_from_snapshot.count
    end

    def availability_zones_count
      2 # This is affected by conf files only, so needs to be hardcoded value
    end

    def assert_table_counts
      expect(ExtManagementSystem.count).to eq 1 # Can this be not hardcoded
      expect(Flavor.count).to              eq compute_data.flavors.count
      expect(AvailabilityZone.count).to    eq availability_zones_count
      expect(FloatingIp.count).to          eq network_data.floating_ips.sum
      expect(AuthPrivateKey.count).to      eq compute_data.key_pairs.count
      expect(SecurityGroup.count).to       eq security_groups_count
      expect(FirewallRule.count).to        eq firewall_rules_count
      expect(CloudNetwork.count).to        eq network_data.networks.count
      expect(CloudSubnet.count).to         eq network_data.subnets.count
      expect(CloudVolume.count).to         eq volumes_count
      expect(VmOrTemplate.count).to        eq vms_count + images_count
      expect(Vm.count).to                  eq vms_count
      expect(MiqTemplate.count).to         eq images_count
      # There are 3 disks per each vm: Root disk, Ephemeral disk and Swap disk
      expect(Disk.count).to                eq vms_count * 3
      # One hardware per each VM
      expect(Hardware.count).to            eq vms_count
      # TODO(lsmola) 2 networks per each floatingip assigned, it's kinda weird now, will replace with
      # neutron models, then the number of networks will fit the number of neutron networks
      # expect(Network.count).to           eq vms_count * 2

      expect(OperatingSystem.count).to     eq 0
      expect(Snapshot.count).to            eq 0
      expect(SystemService.count).to       eq 0
      expect(GuestDevice.count).to         eq 0
      expect(CustomAttribute.count).to     eq 0

      # Just check that Relationship are not empty
      expect(Relationship.count).to        be > 0
      # Just check that queue is not empty
      expect(MiqQueue.count).to            be > 0
    end

    def assert_ems
      @ems.should have_attributes(
        :api_version => nil, # TODO: test for v2 v3 when keystone v3 patch lands
        :uid_ems     => nil
      )

      expect(@ems.flavors.size).to            eq compute_data.flavors.count
      expect(@ems.availability_zones.size).to eq availability_zones_count
      expect(@ems.floating_ips.size).to       eq network_data.floating_ips.sum
      expect(@ems.key_pairs.size).to          eq compute_data.key_pairs.count
      expect(@ems.security_groups.size).to    eq security_groups_count
      expect(@ems.vms_and_templates.size).to  eq vms_count + images_count
      expect(@ems.vms.size).to                eq vms_count
      expect(@ems.miq_templates.size).to      eq images_count
    end

    def assert_specific_flavor
      assert_objects_with_hashes(ManageIQ::Providers::Openstack::CloudManager::Flavor.all,
                                 compute_data.flavors,
                                 compute_data.flavor_translate_table,
                                 {:ram => -> (x) { x * 1_024 * 1_024 }},
                                 [:is_public, :disk, :ephemeral, :swap]) # TODO(lsmola) model blacklisted attrs

      ManageIQ::Providers::Openstack::CloudManager::Flavor.all.each do |flavor|
        expect(flavor.ext_management_system).to eq @ems
        # TODO(lsmola) expose below to Builder's data
        expect(flavor.enabled).to               eq true
        expect(flavor.cpu_cores).to             eq nil
        expect(flavor.description).to           eq nil
      end
    end

    def assert_specific_az
      # This tests OpenStack functionality more than ManageIQ
      @nova_az = ManageIQ::Providers::Openstack::CloudManager::AvailabilityZone.where(
        :type => ManageIQ::Providers::Openstack::CloudManager::AvailabilityZone, :ems_id => @ems.id).first
      # standard openstack AZs have their ems_ref set to their name ("nova" in the test case)...
      # the "null" openstack AZ has a unique ems_ref and name
      @nova_az.should have_attributes(
        :ems_ref => @nova_az.name
      )
    end

    def assert_availability_zone_null
      # This tests OpenStack functionality more than ManageIQ
      @az_null = ManageIQ::Providers::Openstack::CloudManager::AvailabilityZoneNull.where(:ems_id => @ems.id).first
      @az_null.should have_attributes(
        :ems_ref => "null_az"
      )
    end

    def assert_specific_tenant
      assert_objects_with_hashes(CloudTenant.all, identity_data.projects)

      CloudTenant.all.each do |tenant|
        tenant.should be_kind_of(CloudTenant)
        tenant.ext_management_system.should == @ems
      end
    end

    def assert_key_pairs
      assert_objects_with_hashes(ManageIQ::Providers::Openstack::CloudManager::AuthKeyPair.all, compute_data.key_pairs)
    end

    def assert_specific_security_groups
      # We don't want to compare default groups
      without_default = ManageIQ::Providers::Openstack::CloudManager::SecurityGroup.all.select do |x|
        x[:name] != 'default'
      end

      # Compare security groups to expected
      assert_objects_with_hashes(without_default, network_data.security_groups)

      without_default.each do |security_group|
        send("assert_security_group_rules_#{networking_service}", security_group)
      end
    end

    def assert_security_group_rules_neutron(security_group)
      security_group.ems_ref.should be_guid
      # Each security group starts with these rules created
      default_test_data = [{
        :direction => "outbound",
        :protocol  => "",
        :ethertype => "IPv4"
      }, {
        :direction => "outbound",
        :protocol  => "",
        :ethertype => "IPv6"
      }]

      test_data = network_data.security_group_rules(security_group.name) || []
      test_data += default_test_data

      assert_objects_with_hashes(security_group.firewall_rules,
                                 test_data,
                                 network_data.security_groups_rule_translate_table,
                                 'ingress' => 'inbound', 'egress' => 'outbound')
    end

    def assert_security_group_rules_nova(security_group)
      test_data = network_data.security_group_rules(security_group.name) || []
      assert_objects_with_hashes(security_group.firewall_rules,
                                 test_data,
                                 network_data.security_groups_rule_translate_table,
                                 {:ip_range => -> (x) { x ? x[:cidr] : x }},
                                 [:group])
    end

    def assert_specific_network
      networks = CloudNetwork.all

      # Compare security groups to expected
      assert_objects_with_hashes(networks, network_data.networks, network_data.network_translate_table)

      networks.each do |network|
        network.ems_ref.should be_guid

        assert_objects_with_hashes(network.cloud_subnets,
                                   network_data.subnets(network.name),
                                   network_data.subnet_translate_table,
                                   {:ip_version => -> (x) { "ipv#{x}" }},
                                   [:allocation_pools]) # TODO(lsmola) model blacklisted attrs
      end
    end

    def assert_specific_templates
      # TODO(lsmola) make aki and ari part of the Builder's data
      without_aki_and_ari = ManageIQ::Providers::Openstack::CloudManager::Template.all.select do |x|
        !(x.name =~ /(-aki|-ari)/)
      end

      assert_objects_with_hashes(without_aki_and_ari,
                                 image_data.images + image_data.servers_snapshots)

      # TODO(lsmola) expose below in Builder's data
      without_aki_and_ari.each do |template|
        template.should have_attributes(
          :template              => true,
          #:publicly_available    => is_public, # is not exposed now
          :ems_ref_obj           => nil,
          :vendor                => "OpenStack",
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
        template.ems_ref.should be_guid

        expect(template.ext_management_system).to  eq @ems
        expect(template.operating_system).to       be_nil # TODO: This should probably not be nil
        expect(template.custom_attributes.size).to eq 0
        expect(template.snapshots.size).to         eq 0
        expect(template.hardware).to               be_nil

        expect(template.parent).to                 be_nil
      end
    end

    def assert_specific_vms
      assert_objects_with_hashes(ManageIQ::Providers::Openstack::CloudManager::Vm.all,
                                 compute_data.servers + compute_data.servers_from_snapshot,
                                 {},
                                 {},
                                 [:key_name, :security_groups])

      assert_specific_vm("EmsRefreshSpec-PoweredOn", :power_state => "on",)
      assert_specific_vm("EmsRefreshSpec-Paused",    :power_state => "paused",)
      assert_specific_vm("EmsRefreshSpec-Suspended", :power_state => "suspended",)

      assert_specific_template_created_from_vm
      assert_specific_vm_created_from_snapshot_template
    end

    def assert_specific_vm(vm_name, attributes)
      vm = ManageIQ::Providers::Openstack::CloudManager::Vm.where(:name => vm_name).first
      vm_expected = compute_data.servers.detect { |x| x[:name] == vm_name }

      vm.should have_attributes({
        :template              => false,
        :cloud                 => true,
        :ems_ref_obj           => nil,
        :vendor                => "OpenStack",
        :power_state           => "on",
        :location              => "unknown",
        :tools_status          => nil,
        :boot_time             => nil,
        :standby_action        => nil,
        :connection_state      => "connected",
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
      }.merge(attributes))

      expect(vm.ext_management_system).to  eq @ems
      # TODO(lsmola) expose to Builder's data
      expect(vm.availability_zone).to      be_kind_of(ManageIQ::Providers::Openstack::CloudManager::AvailabilityZone)
      # We don't know which IP has been assigned
      expect(vm.floating_ip).to            be_kind_of(ManageIQ::Providers::Openstack::CloudManager::FloatingIp)
      expect(vm.flavor.name).to            eq vm_expected[:__flavor_name]
      expect(vm.key_pairs.map(&:name)).to  eq [vm_expected[:key_name]]
      expect(vm.genealogy_parent.name).to  eq vm_expected[:__image_name]
      expect(vm.operating_system).to       be_nil # TODO: This should probably not be nil
      expect(vm.custom_attributes.size).to eq 0
      expect(vm.snapshots.size).to         eq 0

      if vm_expected[:security_groups].kind_of?(Array)
        vm.security_groups.map(&:name).should match_array vm_expected[:security_groups]
      else
        expect(vm.security_groups.map(&:name)).to eq [vm_expected[:security_groups]]
      end

      vm.hardware.should have_attributes(
        :numvcpus      => vm.flavor.cpus,
        :memory_cpu    => vm.flavor.memory / (1_024 * 1_024), # MB
        :disk_capacity => 2.5.gigabytes # TODO(lsmola) Where is this coming from?
      )

      # Types hardcoded in flavor, I think there can't be different count
      expect(vm.hardware.disks.size).to eq 3

      # TODO(lsmola) the flavor disk data should be stored in Flavor model, getting it from test data now
      flavor_expected = compute_data.flavors.detect { |x| x[:name] == vm.flavor.name }

      disk = vm.hardware.disks.find_by_device_name("Root disk")
      disk.should have_attributes(
        :device_name => "Root disk",
        :device_type => "disk",
        :size        => flavor_expected[:disk].gigabyte
      )
      disk = vm.hardware.disks.find_by_device_name("Ephemeral disk")
      disk.should have_attributes(
        :device_name => "Ephemeral disk",
        :device_type => "disk",
        :size        => flavor_expected[:ephemeral].gigabyte
      )
      disk = vm.hardware.disks.find_by_device_name("Swap disk")
      disk.should have_attributes(
        :device_name => "Swap disk",
        :device_type => "disk",
        :size        => flavor_expected[:swap].megabytes
      )

      # TODO(lsmola) this is all bad, it should be done accoring to Builder's data, will change
      # when clud network models are merged in and used for refresh
      expect(vm.hardware.networks.size).to eq 2
      network_public = vm.hardware.networks.where(:description => "public").first
      network_public.should have_attributes(
        :description => "public",
      )

      network_private = vm.hardware.networks.where(:description => "private").first
      network_private.should have_attributes(
        :description => "private",
      )
    end

    # TODO(lsmola) specific checks below, do we need them?
    def assert_specific_template_created_from_vm
      @snap = ManageIQ::Providers::Openstack::CloudManager::Template.where(
        :name => "EmsRefreshSpec-PoweredOn-SnapShot").first
      @snap.should_not be_nil
      # FIXME: @snap.parent.should == @vm
    end

    def assert_specific_vm_created_from_snapshot_template
      t = ManageIQ::Providers::Openstack::CloudManager::Vm.where(:name => "EmsRefreshSpec-PoweredOn-FromSnapshot").first
      t.parent.should == @snap
    end

    def assert_relationship_tree
      @ems.descendants_arranged.should match_relationship_tree({})
    end
  end
end
