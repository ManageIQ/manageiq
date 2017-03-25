require 'tools/environment_builders/openstack/services/compute/data'
require 'tools/environment_builders/openstack/services/identity/data/keystone_v2'
require 'tools/environment_builders/openstack/services/identity/data/keystone_v3'
require 'tools/environment_builders/openstack/services/image/data'
require 'tools/environment_builders/openstack/services/network/data/neutron'
require 'tools/environment_builders/openstack/services/network/data/nova'
require 'tools/environment_builders/openstack/services/orchestration/data'
require 'tools/environment_builders/openstack/services/storage/data'
require 'tools/environment_builders/openstack/services/volume/data'

require_relative 'refresh_spec_environments'
require_relative 'refresh_spec_helpers'
require_relative 'refresh_spec_matchers'

require 'fog/openstack'

module Openstack
  module RefreshSpecCommon
    def self.included(klass)
      klass.class_eval do
        include RefreshSpecEnvironments
        include RefreshSpecHelpers
        include RefreshSpecMatchers
      end
    end

    def stub_excon_errors
      forbidden = Excon::Errors::Forbidden
      not_found = Excon::Errors::NotFound

      # Error in all stack relations
      allow_any_instance_of(Fog::Orchestration::OpenStack::Stack).to receive(:outputs).and_raise(forbidden, "Fog::Orchestration::OpenStack::Stack.outputs Forbidden")
      allow_any_instance_of(Fog::Orchestration::OpenStack::Stack).to receive(:resources).and_raise(not_found, "Fog::Orchestration::OpenStack::Stack.resources NotFound")
      allow_any_instance_of(Fog::Orchestration::OpenStack::Stack).to receive(:parameters).and_raise(not_found, "Fog::Orchestration::OpenStack::Stack.parameters NotFound")
      allow_any_instance_of(Fog::Orchestration::OpenStack::Stack).to receive(:template).and_raise(not_found, "Fog::Orchestration::OpenStack::Stack.template NotFound")

      # Error in directory relation
      allow_any_instance_of(Fog::Storage::OpenStack::Directory).to receive(:files).and_raise(not_found, "Fog::Storage::OpenStack::Directory Files NotFound")

      # Error in Availability zones list
      allow_any_instance_of(Fog::Compute::OpenStack::Real).to receive(:availability_zones).and_raise(forbidden, "Fog::Compute::OpenStack::Real.availability_zones Forbidden")
      allow_any_instance_of(Fog::Volume::OpenStack::Real).to  receive(:availability_zones).and_raise(not_found, "Fog::Volume::OpenStack::Real.availability_zones NotFound")
      allow_any_instance_of(Fog::Compute::OpenStack::AvailabilityZones).to receive(:summary).and_raise(forbidden, "Fog::Compute::OpenStack::AvailabilityZones.summary Forbidden")
      allow_any_instance_of(Fog::Volume::OpenStack::AvailabilityZones).to  receive(:summary).and_raise(not_found, "Fog::Volume::OpenStack::AvailabilityZones.summary NotFound")
      # Error in list of quotas
      allow_any_instance_of(Fog::Compute::OpenStack::Real).to receive(:get_quota).and_raise(forbidden, "Fog::Compute::OpenStack::Real.get_quota Forbidden")
      allow_any_instance_of(Fog::Network::OpenStack::Real).to receive(:get_quota).and_raise(not_found, "Fog::Network::OpenStack::Real.get_quota NotFound")
      allow_any_instance_of(Fog::Volume::OpenStack::Real).to  receive(:get_quota).and_raise(not_found, "Fog::Volume::OpenStack::Real.get_quota NotFound")

      # And random error caught by handled_list
      allow_any_instance_of(Fog::Compute::OpenStack::KeyPairs).to receive(:all).and_raise(not_found, "Fog::Compute::OpenStack::KeyPairs.all NotFound")
      allow_any_instance_of(Fog::Compute::OpenStack::Flavors).to receive(:all).and_raise(forbidden, "Fog::Compute::OpenStack::Flavors.all Forbidden")
    end

    def assert_with_errors
      expect(OrchestrationStack.count).to          eq orchestration_data.stacks.count
      expect(OrchestrationStackParameter.count).to eq 0
      expect(OrchestrationStackResource.count).to  eq 0
      expect(OrchestrationStackOutput.count).to    eq 0
      expect(OrchestrationTemplate.count).to       eq 0

      expect(CloudObjectStoreContainer.count).to   eq storage_data.directories.count
      expect(CloudObjectStoreObject.count).to      eq 0
      expect(CloudResourceQuota.count).to          eq 0
      expect(AuthPrivateKey.count).to              eq 0
      expect(AvailabilityZone.count).to            eq 1 # just NoZone

      # We have broken flavor list, but there is fallback for private flavors using get, which will collect used flavors
      expect(Flavor.count).to              eq 2

      expect(ExtManagementSystem.count).to               eq 4 # Can this be not hardcoded?
      expect(security_groups_without_defaults.count).to  eq security_groups_count
      expect(firewall_without_defaults.count).to         eq firewall_rules_count
      expect(FloatingIp.count).to                        eq network_data.floating_ips.sum
      expect(CloudNetwork.count).to                      eq network_data.networks.count
      expect(CloudSubnet.count).to                       eq network_data.subnets.count
      expect(NetworkRouter.count).to                     eq network_data.routers.count
      expect(CloudVolume.count).to                       eq volumes_count
      expect(VmOrTemplate.count).to                      eq vms_count + images_count
      expect(MiqTemplate.count).to                       eq images_count
      expect(Disk.count).to                              eq disks_count
      expect(Hardware.count).to                          eq vms_count + images_count
      expect(Vm.count).to                                eq vms_count
      expect(OperatingSystem.count).to                   eq 0
      expect(Snapshot.count).to                          eq 0
      expect(SystemService.count).to                     eq 0
      expect(GuestDevice.count).to                       eq 0
      expect(CustomAttribute.count).to                   eq 0
      # Just check that Relationship are not empty
      expect(Relationship.count).to        be > 0
      # Just check that queue is not empty
      expect(MiqQueue.count).to            be > 0

    end

    def assert_with_skips
      # skips configured modules

      # .. but other things are still present:
      expect(Disk.count).to       eq disks_count(true)
      expect(FloatingIp.count).to eq network_data.floating_ips.sum
    end

    def assert_common
      assert_table_counts

      assert_ems
      assert_flavors
      assert_public_flavor_tenant_mapping
      assert_private_flavor_tenant_mapping
      assert_specific_az
      assert_availability_zone_null
      assert_specific_tenant
      assert_key_pairs
      assert_specific_security_groups
      assert_networks
      assert_specific_networks
      assert_subnets
      assert_routers
      assert_specific_routers
      assert_specific_volumes
      assert_specific_templates
      assert_specific_stacks
      assert_specific_vms
      assert_relationship_tree
      assert_cloud_services

      # Assert table counts as last, just for sure. First we compare Hashes of data, so we see the diffs
      assert_table_counts
      assert_table_counts_orchestration
      assert_table_counts_storage
    end

    def volumes_count
      server_volumes_count = compute_data.servers.map do |x|
        x[:__block_devices] ? x[:__block_devices].count { |d| d[:destination_type] == 'volume' && %w(image blank).include?(d[:source_type]) } : 0
      end.sum

      # Volumes count + volumes created from snapshots + volumes created by snapshoting and recreating vm that was
      # booted from volume
      volume_data.volumes.count + volume_data.volumes_from_snapshots.count + server_volumes_count
    end

    def volume_snapshots_count
      volume_data.volume_snapshots.count
    end

    def firewall_rules_count
      # Number of defined rules
      count = network_data.security_group_rules.count
      # Neutron puts there + 4 default rules for each default security group + 2 empty default rules for each security
      # group created
      count += network_data.security_groups.count * 2 if neutron_networking?
      count
    end

    def default_security_groups_count
      # There is default security group per each tenant
      count = identity_data.projects.count
      # Neutron puts there one extra security group, that is not associated to any tenant
      count += 1 if neutron_networking?
      count
    end

    def security_groups_count
      # Number of defined security groups + default group per each project, that is created automatically
      network_data.security_groups.count
    end

    def images_count
      # Images + snaphosts + Number of shelved instances
      image_data.images.count + image_data.servers_snapshots.count + 1
    end

    def expected_stack_parameters_count
      # We ignore AWS params added there by Heat
      OrchestrationStackParameter.all.to_a.delete_if { |x| x.name.include?("AWS::") || x.name.include?("OS::") }.count
    end

    def stack_parameters_count
      orchestration_data.stacks.count * orchestration_data.template_parameters.count
    end

    def stack_resources_count
      orchestration_data.stacks.count * orchestration_data.template_resources.count
    end

    def stack_outputs_count
      orchestration_data.stacks.count * orchestration_data.template_outputs.count
    end

    def stack_templates_count
      # we have one template for now
      1
    end

    def all_vms_and_stacks
      all_vms = compute_data.servers + compute_data.servers_from_snapshot
      all_vms += orchestration_data.stacks if orchestration_supported?
      all_vms
    end

    def vms_count
      # VMs + Vms created from snapshots + stacks (each stack has one vm)
      all_vms_and_stacks.count
    end

    def disks_count(with_volumes = true)
      # There are possibly 3 disks per each vm: Root disk, Ephemeral disk and Swap disk, depends on flavor
      all_vms_and_stacks.sum do |vm_or_stack|
        disks_count_for_vm(vm_or_stack, with_volumes)
      end
    end

    def disks_count_for_vm(vm_or_stack, with_volumes = true)
      flavor = compute_data.flavors.detect do |x|
        x[:name] == vm_or_stack[:__flavor_name] || x[:name] == vm_or_stack.fetch_path(:parameters, "instance_type")
      end
      # Count only disks that have size bigger that 0
      disks_count = (flavor[:disk] > 0 ? 1 : 0) + (flavor[:ephemeral] > 0 ? 1 : 0) + (flavor[:swap] > 0 ? 1 : 0)

      # May need after linkage is done
      if with_volumes && vm_or_stack[:__block_devices]
        disks_count +=
          vm_or_stack[:__block_devices].count { |d| d[:destination_type] == 'volume' && d[:boot_index] != 0 }
      end

      disks_count
    end

    def availability_zones_count
      2 # This is affected by conf files only, so needs to be hardcoded value
    end

    def assert_table_counts
      expect(ExtManagementSystem.count).to               eq 4 # Can this be not hardcoded? self/network/cinder/swift
      expect(Flavor.count).to                            eq compute_data.flavors.count
      expect(AvailabilityZone.count).to                  eq availability_zones_count
      expect(FloatingIp.count).to                        eq network_data.floating_ips.sum
      expect(AuthPrivateKey.count).to                    eq compute_data.key_pairs.count
      expect(security_groups_without_defaults.count).to  eq security_groups_count
      expect(firewall_without_defaults.count).to         eq firewall_rules_count
      expect(CloudNetwork.count).to                      eq network_data.networks.count
      expect(CloudSubnet.count).to                       eq network_data.subnets.count
      expect(NetworkRouter.count).to                     eq network_data.routers.count
      expect(CloudVolume.count).to                       eq volumes_count
      expect(VmOrTemplate.count).to                      eq vms_count + images_count
      expect(Vm.count).to                                eq vms_count
      expect(MiqTemplate.count).to                       eq images_count
      expect(Disk.count).to                              eq disks_count
      # One hardware per each VM
      expect(Hardware.count).to                          eq vms_count + images_count
      # TODO(lsmola) 2 networks per each floatingip assigned, it's kinda weird now, will replace with
      # neutron models, then the number of networks will fit the number of neutron networks
      # expect(Network.count).to           eq vms_count * 2
      expect(OperatingSystem.count).to                   eq 0
      expect(Snapshot.count).to                          eq 0
      expect(SystemService.count).to                     eq 0
      expect(GuestDevice.count).to                       eq 0
      expect(CustomAttribute.count).to                   eq 0

      # Just check that Relationship are not empty
      expect(Relationship.count).to        be > 0
      # Just check that queue is not empty
      expect(MiqQueue.count).to            be > 0
      expect(CloudService.count).to        be > 0
      expect(CloudResourceQuota.count).to  be > 0

    end

    def assert_table_counts_orchestration
      if orchestration_supported?
        expect(OrchestrationStack.count).to         eq orchestration_data.stacks.count
        expect(expected_stack_parameters_count).to  eq stack_parameters_count
        expect(OrchestrationStackResource.count).to eq stack_resources_count
        expect(OrchestrationStackOutput.count).to   eq stack_outputs_count
        expect(OrchestrationTemplate.count).to      eq stack_templates_count
      end
    end

    def assert_table_counts_storage
      if storage_supported?
        volumes_backup = CloudObjectStoreContainer.where({ key: "volumes_backup" })
        expect(CloudObjectStoreContainer.count).to eq storage_data.directories.count + volumes_backup.count
        expect(CloudObjectStoreObject.count).to    eq storage_data.files.count
      end
    end

    def assert_ems
      expect(@ems).to have_attributes(
        :api_version => identity_service.to_s,
        :uid_ems     => identity_service == :v3 ? 'default' : nil
      )

      expect(@ems.flavors.size).to            eq compute_data.flavors.count
      expect(@ems.availability_zones.size).to eq availability_zones_count
      expect(@ems.floating_ips.size).to       eq network_data.floating_ips.sum
      expect(@ems.key_pairs.size).to          eq compute_data.key_pairs.count
      security_groups_count = @ems.security_groups.count { |x| x.name != 'default' }
      expect(security_groups_count).to        eq security_groups_count
      expect(@ems.vms_and_templates.size).to  eq vms_count + images_count
      expect(@ems.vms.size).to                eq vms_count
      expect(@ems.miq_templates.size).to      eq images_count
      expect(@ems.cloud_networks.size).to     eq network_data.networks.count

      if neutron_networking?
        expect(@ems.public_networks.first).to  be_kind_of(ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Public)
        expect(@ems.private_networks.first).to be_kind_of(ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Private)
      end
    end

    def assert_flavors
      gigabyte_transformation = -> (x) { x.gigabyte }
      blacklisted_attributes = [:is_public] # TODO(lsmola) model blacklisted attrs
      # Disks are supported from havana and above apparently
      blacklisted_attributes += [:disk, :ephemeral, :swap] if environment_release_number < 4

      assert_objects_with_hashes(ManageIQ::Providers::Openstack::CloudManager::Flavor.all,
                                 compute_data.flavors,
                                 compute_data.flavor_translate_table,
                                 {:ram       => -> (x) { x * 1_024 * 1_024 },
                                  :disk      => gigabyte_transformation,
                                  :ephemeral => gigabyte_transformation,
                                  :swap      => -> (x) { x.megabyte }},
                                 blacklisted_attributes)

      ManageIQ::Providers::Openstack::CloudManager::Flavor.all.each do |flavor|
        # TODO(lsmola) expose below to Builder's data
        expected_ephemeral_disk_count =
          if flavor.ephemeral_disk_size.nil?
            nil
          elsif flavor.ephemeral_disk_size.to_i > 0
            1
          else
            0
          end

        expect(flavor.ext_management_system).to eq @ems
        expect(flavor.enabled).to               eq true
        expect(flavor.cpu_cores).to             eq nil
        expect(flavor.description).to           eq nil
        expect(flavor.ephemeral_disk_count).to  eq expected_ephemeral_disk_count
      end
    end

    def assert_public_flavor_tenant_mapping
      @other_flavors = ManageIQ::Providers::Openstack::CloudManager::Flavor.where(:publicly_available => true)
      @other_flavors.each do |f|
        expect(f.cloud_tenants.length).to eq CloudTenant.count
      end
    end

    def assert_private_flavor_tenant_mapping
      @private_flavor = ManageIQ::Providers::Openstack::CloudManager::Flavor.where(:publicly_available => false).first
      expect(@private_flavor.cloud_tenants.length).to eq 1
    end

    def assert_specific_az
      # This tests OpenStack functionality more than ManageIQ
      @nova_az = ManageIQ::Providers::Openstack::CloudManager::AvailabilityZone.where(
        :type => ManageIQ::Providers::Openstack::CloudManager::AvailabilityZone.name, :ems_id => @ems.id).first
      # standard openstack AZs have their ems_ref set to their name ("nova" in the test case)...
      # the "null" openstack AZ has a unique ems_ref and name
      expect(@nova_az).to have_attributes(
        :ems_ref => @nova_az.name
      )
    end

    def assert_availability_zone_null
      # This tests OpenStack functionality more than ManageIQ
      @az_null = ManageIQ::Providers::Openstack::CloudManager::AvailabilityZoneNull.where(:ems_id => @ems.id).first
      expect(@az_null).to have_attributes(
        :ems_ref => "null_az"
      )
    end

    def assert_specific_tenant
      assert_objects_with_hashes(CloudTenant.all, identity_data.projects)

      identity_data.projects.each do |project|
        next unless project[:__parent_name]

        parent_id = CloudTenant.find_by(:name => project[:__parent_name]).try(:id)
        cloud_tenant = CloudTenant.find_by(:name => project[:name])
        expect(cloud_tenant.parent_id).to eq(parent_id)
      end

      CloudTenant.all.each do |tenant|
        expect(tenant).to be_kind_of(CloudTenant)
        expect(tenant.ext_management_system).to eq(@ems)
      end
    end

    def assert_key_pairs
      assert_objects_with_hashes(ManageIQ::Providers::Openstack::CloudManager::AuthKeyPair.all, compute_data.key_pairs)
    end

    def firewall_without_defaults
      security_groups_without_defaults.collect(&:firewall_rules).flatten
    end

    def security_groups_without_defaults
      SecurityGroup.all.select do |x|
        x[:name] != 'default'
      end
    end

    def assert_specific_security_groups
      # We don't want to compare default groups
      without_default = security_groups_without_defaults

      # Compare security groups to expected
      assert_objects_with_hashes(without_default, network_data.security_groups)

      without_default.each do |security_group|
        send("assert_security_group_rules_#{networking_service}", security_group)
      end
    end

    def assert_security_group_rules_neutron(security_group)
      expect(security_group.ems_ref).to be_guid
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

    def network_vms(network)
      (compute_data.servers + compute_data.servers_from_snapshot).select do |x|
        x[:__network_names].include?(network.name)
      end
    end

    def network_stacks(network)
      orchestration_data.stacks.select do |x|
        x[:parameters][:__network_name] == network.name
      end
    end

    def assert_networks
      return unless neutron_networking?

      networks = CloudNetwork.all

      blacklisted_attributes  = []
      # Havana and below doesn;t support provider networks
      blacklisted_attributes += ["provider:network_type", "provider:physical_network"] if environment_release_number < 5
      # Compare networks to expected
      assert_objects_with_hashes(networks,
                                 network_data.networks,
                                 network_data.network_translate_table,
                                 {},
                                 blacklisted_attributes)

      networks.each do |network|
        expect(network.ems_ref).to be_guid

        assert_objects_with_hashes(network.cloud_subnets,
                                   network_data.subnets(network.name),
                                   network_data.subnet_translate_table,
                                   {:ip_version => -> (x) { "ipv#{x}" }},
                                   [:allocation_pools]) # TODO(lsmola) model blacklisted attrs

        if network.external_facing?
          vms = network.private_networks.map { |x| (network_vms(x) + network_stacks(x)) }.flatten.uniq
          expect(network.vms.count).to eq vms.count

          non_stack_vms          = network.vms.select { |x| x.orchestration_stack.blank? }
          non_stack_expected_vms = network.private_networks.map { |x| (network_vms(x)) }.flatten.uniq
          expect(non_stack_vms.map(&:name)).to match_array(non_stack_expected_vms.map { |x| x[:name] })
        else
          vms = network_vms(network) + network_stacks(network)
          expect(network.vms.count).to eq vms.count
          expect(network.vms.count).to eq network.cloud_subnets.to_a.sum { |x| x.vms.count }

          non_stack_vms = network.vms.select { |x| x.orchestration_stack.blank? }
          expect(non_stack_vms.map(&:name)).to match_array(network_vms(network).map { |x| x[:name] })
        end
      end
    end

    def assert_specific_networks
      return unless neutron_networking?

      networks = CloudNetwork.all

      specific_networks = networks.select do |x|
        [network_data.class::PUBLIC_NETWORK_NAME, network_data.class::PRIVATE_NETWORK_NAME].include? x.name
      end

      specific_networks.each do |network|
        expect(network.cloud_tenant).to          be_kind_of(ManageIQ::Providers::Openstack::CloudManager::CloudTenant)
        expect(network.ext_management_system).to be_kind_of(ManageIQ::Providers::Openstack::NetworkManager)
        expect(network.cloud_subnets.count).to   be > 0
        expect(network.cloud_subnets.first).to   be_kind_of(ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet)
        expect(network.vms.count).to             be > 0
        expect(network.vms.first).to             be_kind_of(ManageIQ::Providers::Openstack::CloudManager::Vm)
        expect(network.network_routers.count).to be > 0
        expect(network.network_routers.first).to be_kind_of(ManageIQ::Providers::Openstack::NetworkManager::NetworkRouter)
        if network.external_facing?
          # It's a public network
          expect(network).to be_kind_of(ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Public)
          expect(network.private_networks.count).to be > 0
          expect(network.floating_ips.count).to     be > 0
          expect(network.private_networks.first).to be_kind_of(ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Private)

          assert_objects_with_hashes(network.network_routers, network_data.routers(network.name))
        else
          # It's a private network
          expect(network).to be_kind_of(ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Private)
          expect(network.public_networks.count).to be > 0
          expect(network.public_networks.first).to be_kind_of(ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Public)
        end
      end
    end

    def assert_subnets
      return unless neutron_networking?

      subnets = CloudSubnet.all

      # Compare subnets to expected
      assert_objects_with_hashes(subnets,
                                 network_data.subnets,
                                 network_data.subnet_translate_table,
                                 {:ip_version      => -> (x) { "ipv#{x}" },
                                  :dns_nameservers => -> (x) { x.nil? ? [] : x },
                                  :enable_dhcp     => -> (x) { x.nil? ? true : x }},
                                 [:allocation_pools]) # TODO(lsmola) model blacklisted attrs

      subnets.each do |subnet|
        expect(subnet.ems_ref).to be_guid
      end
    end

    def assert_routers
      return unless neutron_networking?

      network_routers = NetworkRouter.all
      assert_objects_with_hashes(network_routers, network_data.routers)
    end

    def assert_specific_routers
      return unless neutron_networking?

      specific_routers = NetworkRouter.all.select do |x|
        [network_data.class::ROUTER_NAME].include?(x.name)
      end

      specific_routers.each do |network_router|
        expect(network_router.floating_ips.count).to   be > 0
        expect(network_router.floating_ips.first).to   be_kind_of(ManageIQ::Providers::Openstack::NetworkManager::FloatingIp)
        expect(network_router.network_ports.count).to  be > 0
        expect(network_router.network_ports.first).to  be_kind_of(ManageIQ::Providers::Openstack::NetworkManager::NetworkPort)
        expect(network_router.cloud_networks.count).to be > 0
        expect(network_router.cloud_networks.first).to be_kind_of(ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Private)
        expect(network_router.cloud_networks).to match_array network_router.private_networks
        expect(network_router.cloud_network).to        be_kind_of(ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Public)
        expect(network_router.cloud_network).to        be == network_router.public_network
        expect(network_router.vms.first).to            be_kind_of(ManageIQ::Providers::Openstack::CloudManager::Vm)
        expect(network_router.vms.count).to            be > 0
      end
    end

    def assert_specific_volumes
      # TODO(lsmola) assert volumes
      # assert_objects_with_hashes(volumes, volume_data.volumes)
    end


    def assert_specific_directories
      return unless storage_supported?

      directories = CloudObjectStoreContainer.all
      assert_objects_with_hashes(directories, storage_data.directories)

      directories.each do |directory|
        files = directory.cloud_object_store_objects
        next if files.blank?

        assert_objects_with_hashes(files, storage_data.files(directory.key))
        files.each do |file|
          expect(file.content_length).to be > 0
          expect(file.ems_ref).to        eq file.key
        end
      end
    end

    def assert_templates
      # Ignoring shelved VMs, which are generating Image of the same name with suffix ''-shelved'
      templates = ManageIQ::Providers::Openstack::CloudManager::Template.all.reject { |x| x.name.include?("-shelved") }

      assert_objects_with_hashes(templates,
                                 image_data.images + image_data.servers_snapshots,
                                 image_data.images_translate_table,
                                 :is_public => -> (x) { x.nil? ? false : x })
    end

    def assert_specific_templates
      specific_templates = ManageIQ::Providers::Openstack::CloudManager::Template.all.select do |x|
        [image_data.class::IMAGE_NAME].include?(x.name)
      end

      # TODO(lsmola) expose below in Builder's data
      specific_templates.each do |template|
        expect(template).to have_attributes(
          :template              => true,
          #:publicly_available    => is_public, # is not exposed now
          :ems_ref_obj           => nil,
          :vendor                => "openstack",
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
        expect(template.ems_ref).to be_guid

        expect(template.ext_management_system).to  eq @ems
        expect(template.operating_system).to       be_nil # TODO: This should probably not be nil
        expect(template.custom_attributes.size).to eq 0
        expect(template.snapshots.size).to         eq 0
        expect(template.hardware).not_to           be_nil
        expect(template.parent).to                 be_nil
      end
    end

    def assert_specific_stacks
      return unless orchestration_supported?

      stacks = OrchestrationStack.all

      assert_objects_with_hashes(stacks,
                                 orchestration_data.stacks,
                                 orchestration_data.stack_translate_table,
                                 {},
                                 [:template, :parameters])
    end

    def assert_specific_vms
      all_vms = ManageIQ::Providers::Openstack::CloudManager::Vm.all
      if orchestration_supported?
        # When there are orchestration stacks, we will delete them from vm comparing, vm name contains unique
        # id, so it's hard to build it from stack
        stack_vms     = OrchestrationStackResource.select { |x| x.resource_category == "OS::Nova::Server" }
        stack_vms_ids = stack_vms.collect(&:physical_resource)

        all_vms = all_vms.to_a.delete_if { |x| stack_vms_ids.include?(x.ems_ref) }
      end

      assert_objects_with_hashes(all_vms,
                                 compute_data.servers + compute_data.servers_from_snapshot,
                                 {},
                                 {},
                                 [:key_name, :security_groups])

      assert_specific_vm("EmsRefreshSpec-PoweredOn", :power_state => "on",)
      assert_specific_vm("EmsRefreshSpec-Paused",    :power_state => "paused",)
      assert_specific_vm("EmsRefreshSpec-Suspended", :power_state => "suspended",)
      assert_specific_vm("EmsRefreshSpec-Shelved",   :power_state => "shelved_offloaded",)

      assert_specific_template_created_from_vm
      assert_specific_vm_created_from_snapshot_template
    end

    def assert_specific_vm(vm_name, attributes)
      vm = ManageIQ::Providers::Openstack::CloudManager::Vm.where(:name => vm_name).first
      vm_expected = compute_data.servers.detect { |x| x[:name] == vm_name }

      expect(vm).to have_attributes({
        :template              => false,
        :cloud                 => true,
        :ems_ref_obj           => nil,
        :vendor                => "openstack",
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
      expect(vm.floating_ip).to            be_kind_of(ManageIQ::Providers::Openstack::NetworkManager::FloatingIp)
      expect(vm.flavor.name).to            eq vm_expected[:__flavor_name]
      expect(vm.key_pairs.map(&:name)).to  eq [vm_expected[:key_name]]
      expect(vm.genealogy_parent.name).to  eq vm_expected[:__image_name]
      expect(vm.operating_system).to       be_nil # TODO: This should probably not be nil
      expect(vm.custom_attributes.size).to eq 0
      expect(vm.snapshots.size).to         eq 0

      if neutron_networking?
        expect(vm.floating_ips.count).to    be > 0
        expect(vm.floating_ips.first).to    be_kind_of(ManageIQ::Providers::Openstack::NetworkManager::FloatingIp)
        expect(vm.network_ports.count).to   be > 0
        expect(vm.network_ports.first).to   be_kind_of(ManageIQ::Providers::Openstack::NetworkManager::NetworkPort)
        expect(vm.cloud_networks.count).to  be > 0
        expect(vm.cloud_networks).to match_array vm.private_networks
        expect(vm.cloud_networks.first).to  be_kind_of(ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Private)
        expect(vm.cloud_subnets.count).to   be > 0
        expect(vm.cloud_subnets.first).to   be_kind_of(ManageIQ::Providers::Openstack::NetworkManager::CloudSubnet)
        expect(vm.network_routers.count).to be > 0
        expect(vm.network_routers.first).to be_kind_of(ManageIQ::Providers::Openstack::NetworkManager::NetworkRouter)
        expect(vm.public_networks.count).to be > 0
        expect(vm.public_networks.first).to be_kind_of(ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Public)

        expect(vm.fixed_ip_addresses.count).to    be > 0
        expect(vm.floating_ip_addresses.count).to be > 0

        expect(vm.private_networks.map(&:name)).to match_array vm_expected[:__network_names]
        expect(vm.public_networks.first.floating_ips).to include vm.floating_ips.first
        vm.network_ports.each do |network_port|
          if network_port.public_networks.first.floating_ips.count > 0
            expect(network_port.public_networks.first.floating_ips).to include network_port.floating_ip
            expect(network_port.public_networks.first.floating_ips).to include network_port.floating_ips.first
          end
        end
      end

      if vm_expected[:security_groups].kind_of?(Array)
        expect(vm.security_groups.map(&:name)).to match_array vm_expected[:security_groups]
      else
        expect(vm.security_groups.map(&:name)).to eq [vm_expected[:security_groups]]
      end

      expect(vm.hardware).to have_attributes(
        :cpu_sockets   => vm.flavor.cpus,
        :memory_mb     => vm.flavor.memory / 1.megabyte,
        :disk_capacity => 2.5.gigabytes # TODO(lsmola) Where is this coming from?
      )

      expect(vm.hardware.disks.size).to eq disks_count_for_vm(vm_expected)

      # TODO(lsmola) the flavor disk data should be stored in Flavor model, getting it from test data now
      flavor_expected = compute_data.flavors.detect { |x| x[:name] == vm.flavor.name }

      disk = vm.hardware.disks.find_by_device_name("Root disk")
      expect(disk).to have_attributes(
        :device_name => "Root disk",
        :device_type => "disk",
        :size        => flavor_expected[:disk].gigabyte
      )
      disk = vm.hardware.disks.find_by_device_name("Ephemeral disk")
      expect(disk).to have_attributes(
        :device_name => "Ephemeral disk",
        :device_type => "disk",
        :size        => flavor_expected[:ephemeral].gigabyte
      )
      disk = vm.hardware.disks.find_by_device_name("Swap disk")
      expect(disk).to have_attributes(
        :device_name => "Swap disk",
        :device_type => "disk",
        :size        => flavor_expected[:swap].megabytes
      )

      # TODO(lsmola) this is all bad, it should be done accoring to Builder's data, will change
      # when clud network models are merged in and used for refresh
      expect(vm.hardware.networks.size).to eq 2
      network_public = vm.hardware.networks.where(:description => "public").first
      expect(network_public).to have_attributes(
        :description => "public",
      )

      network_private = vm.hardware.networks.where(:description => "private").first
      expect(network_private).to have_attributes(
        :description => "private",
      )
    end

    # TODO(lsmola) specific checks below, do we need them?
    def assert_specific_template_created_from_vm
      @snap = ManageIQ::Providers::Openstack::CloudManager::Template.where(
        :name => "EmsRefreshSpec-PoweredOn-SnapShot").first
      expect(@snap).not_to be_nil
      # FIXME: @snap.parent.should == @vm
    end

    def assert_specific_vm_created_from_snapshot_template
      t = ManageIQ::Providers::Openstack::CloudManager::Vm.where(:name => "EmsRefreshSpec-PoweredOn-FromSnapshot").first
      expect(t.parent).to eq(@snap)
    end

    def assert_relationship_tree
      expect(@ems.descendants_arranged).to match_relationship_tree({})
    end

    def assert_cloud_services
      sources_count = {
        'compute' => 5,
      }
      sources_count.map do |source, count|
        expect(CloudService.where(:source => source).count).to eq count
      end

      executable_names_count = {
        'nova-compute'     => 1,
        'nova-consoleauth' => 1,
        'nova-cert'        => 1,
        'nova-conductor'   => 1,
        'nova-scheduler'   => 1,
      }
      executable_names_count.map do |executable_name, count|
        expect(CloudService.where(:executable_name => executable_name).count).to eq count
      end
    end

    def expect_sync_cloud_tenants_with_tenants_is_queued
      sync_cloud_tenant = MiqQueue.last

      expect(sync_cloud_tenant.method_name).to eq("sync_cloud_tenants_with_tenants")
      expect(sync_cloud_tenant.state).to eq(MiqQueue::STATE_READY)
    end
  end
end
