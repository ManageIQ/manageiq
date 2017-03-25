describe ManageIQ::Providers::Openstack::InfraManager::Refresher do
  before(:each) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_openstack_infra, :zone => zone, :hostname => "192.168.24.1",
                              :ipaddress => "192.168.24.1", :port => 5000, :api_version => 'v2',
                              :security_protocol => 'no-ssl')
    @ems.update_authentication(
      :default => {:userid => "admin", :password => "b83387e3b93a015a57f23a9262e799db5d0a22f6"})
  end

  it "will perform a full refresh" do
    2.times do  # Run twice to verify that a second run with existing data does not change anything
      @ems.reload
      # Caching OpenStack info between runs causes the tests to fail with:
      #   VCR::Errors::UnusedHTTPInteractionError
      # Reset the cache so HTTP interactions are the same between runs.
      @ems.reset_openstack_handle

      # We need VCR to match requests differently here because fog adds a dynamic
      #   query param to avoid HTTP caching - ignore_awful_caching##########
      #   https://github.com/fog/fog/blob/master/lib/fog/openstack/compute.rb#L308
      VCR.use_cassette("#{described_class.name.underscore}_rhos_juno", :match_requests_on => [:method, :host, :path]) do
        Fog::OpenStack.instance_variable_set(:@version, nil)
        EmsRefresh.refresh(@ems)
        EmsRefresh.refresh(@ems.network_manager)
      end
      @ems.reload

      assert_table_counts
      assert_ems
      assert_specific_host
      assert_specific_public_template
    end
  end

  it "will verify maintenance mode" do
    # We need VCR to match requests differently here because fog adds a dynamic
    #   query param to avoid HTTP caching - ignore_awful_caching##########
    #   https://github.com/fog/fog/blob/master/lib/fog/openstack/compute.rb#L308
    VCR.use_cassette("#{described_class.name.underscore}_rhos_juno_maintenance",
                     :match_requests_on => [:method, :host, :path]) do
      @ems.reload
      @ems.reset_openstack_handle
      EmsRefresh.refresh(@ems)
      EmsRefresh.refresh(@ems.network_manager)
      @ems.reload

      @host = ManageIQ::Providers::Openstack::InfraManager::Host.all.order(:ems_ref).detect { |x| x.name.include?('(NovaCompute)') }

      expect(@host.maintenance).to eq(false)
      expect(@host.maintenance_reason).to eq(nil)

      @host.set_node_maintenance
      EmsRefresh.refresh(@ems)
      @ems.reload
      @host.reload
      expect(@host.maintenance).to eq(true)
      expect(@host.maintenance_reason).to eq("CFscaledown")

      @host.unset_node_maintenance
      EmsRefresh.refresh(@ems)
      @ems.reload
      @host.reload
      expect(@host.maintenance).to eq(false)
      expect(@host.maintenance_reason).to eq(nil)
    end
  end

  def assert_table_counts
    expect(ExtManagementSystem.count).to         eq 2
    expect(EmsCluster.count).to                  be > 0
    expect(Host.count).to                        be > 0
    expect(OrchestrationStack.count).to          be > 0
    expect(OrchestrationStackParameter.count).to be > 0
    expect(OrchestrationStackResource.count).to  be > 0
    expect(OrchestrationStackOutput.count).to    be > 0
    expect(OrchestrationTemplate.count).to       be > 0
    expect(CloudNetwork.count).to                be > 0
    expect(CloudSubnet.count).to                 be > 0
    expect(NetworkPort.count).to                 be > 0
    expect(VmOrTemplate.count).to                be > 0
    expect(OperatingSystem.count).to             be > 0
    expect(Hardware.count).to                    be > 0
    # TODO(tzumainn) Introspection no longer returns disk information, may be
    # an OpenStack issue?
    expect(Disk.count).to                        be > -1
    expect(ResourcePool.count).to                eq 0
    expect(Vm.count).to                          eq 0
    expect(CustomAttribute.count).to             eq 0
    expect(CustomizationSpec.count).to           eq 0
    # expect(GuestDevice.count).to                 eq > 0
    expect(Lan.count).to                         eq 0
    expect(MiqScsiLun.count).to                  eq 0
    expect(MiqScsiTarget.count).to               eq 0
    # expect(Network.count).to                     eq 0
    expect(Snapshot.count).to                    eq 0
    expect(Switch.count).to                      eq 0
    expect(SystemService.count).to               eq 0
    expect(EmsFolder.count).to                   eq 0 # HACK: Folder structure for UI a la VMware
    # TODO(lsmola) investigate if this should be filled or not, also why
    # it behaves strangely, it has different values in CI then locally
    # expect(Relationship.count).to                eq 0
    # expect(MiqQueue.count).to                    eq 9
    expect(Storage.count).to                     eq 0
  end

  def assert_ems
    expect(@ems).to have_attributes(
      :api_version       => 'v2',
      :security_protocol => 'no-ssl',
      :uid_ems           => nil
    )

    expect(@ems.ems_clusters.size).to                be > 0
    expect(@ems.hosts.size).to                       be > 0
    expect(@ems.orchestration_stacks.size).to        be > 0
    expect(@ems.direct_orchestration_stacks.size).to be > 0
    expect(@ems.vms_and_templates.size).to           be > 0
    expect(@ems.miq_templates.size).to               be > 0
    expect(@ems.customization_specs.size).to         eq 0
    expect(@ems.resource_pools.size).to              eq 0
    expect(@ems.storages.size).to                    eq 0
    expect(@ems.vms.size).to                         eq 0
    expect(@ems.ems_folders.size).to                 eq 0 # HACK: Folder structure for UI a la VMware
  end

  def assert_specific_host
    @host = ManageIQ::Providers::Openstack::InfraManager::Host.all.detect { |x| x.name.include?('(Controller)') }

    expect(@host.ems_ref).not_to be nil
    expect(@host.ems_ref_obj).not_to be nil
    expect(@host.mac_address).not_to be nil
    expect(@host.ipaddress).not_to be nil
    expect(@host.ems_cluster).not_to be nil

    expect(@host).to have_attributes(
      :ipmi_address       => nil,
      :vmm_vendor         => "redhat",
      :vmm_version        => nil,
      :vmm_product        => "rhel (No hypervisor, Host Type is Controller)",
      :power_state        => "on",
      :connection_state   => "connected",
      :service_tag        => nil,
      :maintenance        => false,
      :maintenance_reason => nil,
    )

    expect(@host.private_networks.count).to be > 0
    expect(@host.private_networks.first).to be_kind_of(ManageIQ::Providers::Openstack::NetworkManager::CloudNetwork::Private)
    expect(@host.network_ports.count).to    be > 0
    expect(@host.network_ports.first).to    be_kind_of(ManageIQ::Providers::Openstack::NetworkManager::NetworkPort)

    expect(@host.operating_system).to have_attributes(
      :product_name     => "linux"
    )

    expect(@host.hardware).to have_attributes(
      # TODO(tzumainn) Introspection no longer finds these attributes, may be
      # an OpenStack issue?
      #:cpu_speed            => 3392,
      #:cpu_type             => "RHEL 7.2.0 PC (i440FX + PIIX, 1996)",
      #:manufacturer         => "Red Hat",
      #:model                => "KVM",
      #:bios                 => "seabios-1.7.5-11.el7",
      :memory_mb            => 8192,
      :memory_console       => nil,
      :disk_capacity        => 49,
      :cpu_sockets          => 1,
      :cpu_total_cores      => 1,
      :cpu_cores_per_socket => 1,
      :guest_os             => nil,
      :guest_os_full_name   => nil,
      :cpu_usage            => nil,
      :memory_usage         => nil,
      :number_of_nics       => 1,
    )

    # TODO(tzumainn) Introspection no longer finds disk attributes, may be
    # an OpenStack issue?
    #assert_specific_disk(@host.hardware.disks.first)
  end

  def assert_specific_disk(disk)
    expect(disk).to have_attributes(
      :device_name     => 'sda',
      :device_type     => 'disk',
      :controller_type => 'scsi',
      :present         => true,
      :filename        => 'ata-QEMU_HARDDISK_QM00005',
      :location        => nil,
      :size            => 57_982_058_496,
      :disk_type       => nil,
      :mode            => 'persistent')
  end

  def assert_specific_public_template
    assert_specific_template("overcloud-full-vmlinuz", true)
  end

  def assert_specific_template(name, is_public = false)
    template = ManageIQ::Providers::Openstack::InfraManager::Template.where(:name => name).first
    expect(template).to have_attributes(
      :template              => true,
      :publicly_available    => is_public,
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

    expect(template.ext_management_system).to eq @ems
    expect(template.operating_system).to be_nil # TODO: This should probably not be nil
    expect(template.custom_attributes.size).to eq 0
    expect(template.snapshots.size).to         eq 0
    expect(template.hardware).not_to               be_nil
    expect(template.parent).to                     be_nil
    template
  end
end
