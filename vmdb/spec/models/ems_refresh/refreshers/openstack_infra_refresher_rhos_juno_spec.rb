
require "spec_helper"

describe EmsRefresh::Refreshers::OpenstackInfraRefresher do
  before(:each) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_openstack_infra, :zone => zone, :hostname => "192.0.2.1",
                              :ipaddress => "192.0.2.1", :port => 5000)
    @ems.update_authentication(
        :default => {:userid => "admin", :password => "c9c9a1201fdf9fb217bff3a2f4e3fb89f589f355"})
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
        EmsRefresh.refresh(@ems)
      end
      @ems.reload

      assert_table_counts
      assert_ems
      assert_specific_host
      assert_specific_public_template
    end
  end

  def assert_table_counts
    ExtManagementSystem.count.should         == 1
    EmsFolder.count.should                   == 0 # HACK: Folder structure for UI a la VMware
    EmsCluster.count.should                  == 2
    Host.count.should                        == 5
    OrchestrationStack.count.should          == 1
    OrchestrationStackParameter.count.should == 168
    OrchestrationStackResource.count.should  == 88
    OrchestrationStackOutput.count.should    == 1
    OrchestrationTemplate.count.should       == 1
    ResourcePool.count.should                == 0
    Vm.count.should                          == 0
    VmOrTemplate.count.should                == 5
    CustomAttribute.count.should             == 0
    CustomizationSpec.count.should           == 0
    Disk.count.should                        == 5
    GuestDevice.count.should                 == 0
    Hardware.count.should                    == 5
    Lan.count.should                         == 0
    MiqScsiLun.count.should                  == 0
    MiqScsiTarget.count.should               == 0
    Network.count.should                     == 0
    OperatingSystem.count.should             == 5
    Snapshot.count.should                    == 0
    Switch.count.should                      == 0
    SystemService.count.should               == 0
    Relationship.count.should                == 0
    MiqQueue.count.should                    == 8
    Storage.count.should                     == 0
  end

  def assert_ems
    @ems.should have_attributes(
      :api_version => nil,
      :uid_ems     => nil
    )

    @ems.ems_folders.size.should          == 0 # HACK: Folder structure for UI a la VMware
    @ems.ems_clusters.size.should         == 2
    @ems.resource_pools.size.should       == 0
    @ems.storages.size.should             == 0
    @ems.hosts.size.should                == 5
    @ems.orchestration_stacks.size.should == 1
    @ems.vms_and_templates.size.should    == 5
    @ems.vms.size.should                  == 0
    @ems.miq_templates.size.should        == 5
    @ems.customization_specs.size.should  == 0
  end

  def assert_specific_host
    @host = HostOpenstackInfra.all.select { |x| x.name.include?('(Controller)') }.first

    @host.ems_ref.should_not be nil
    @host.ems_ref_obj.should_not be nil
    @host.mac_address.should_not be nil
    @host.ipaddress.should_not be nil

    @host.should have_attributes(
      :ipmi_address     => nil,
      :vmm_vendor       => "RedHat",
      :vmm_version      => nil,
      :vmm_product      => "rhel (No hypervisor, Host Type is Controller)",
      :power_state      => "on",
      :connection_state => "connected",
      :service_tag      => nil,
    )

    @host.operating_system.should have_attributes(
      :product_name     => "linux"
    )

    @host.hardware.should have_attributes(
      :cpu_speed          => 2000,
      :cpu_type           => "RHEL 7.1.0 PC (i440FX + PIIX, 1996)",
      :manufacturer       => "Red Hat",
      :model              => "KVM",
      :memory_cpu         => 4096,  # MB
      :memory_console     => nil,
      :disk_capacity      => 40,
      :numvcpus           => 1,
      :logical_cpus       => 1,
      :cores_per_socket   => 1,
      :guest_os           => nil,
      :guest_os_full_name => nil,
      :cpu_usage          => nil,
      :memory_usage       => nil,
      :number_of_nics     => 1,
      :bios               => "seabios-1.7.5-8.el7"
    )

    assert_specific_disk(@host.hardware.disks.first)
  end

  def assert_specific_disk(disk)
    disk.should have_attributes(
      :device_name     => 'sda',
      :device_type     => 'disk',
      :controller_type => 'scsi',
      :present         => true,
      :filename        => 'ata-QEMU_HARDDISK_QM00005',
      :location        => nil,
      :size            => 44,
      :disk_type       => nil,
      :mode            => 'persistent')
  end

  def assert_specific_public_template
    assert_specific_template("overcloud-full-vmlinuz", true)
  end

  def assert_specific_template(name, is_public = false)
    template = TemplateOpenstack.where(:name => name).first
    template.should have_attributes(
      :template              => true,
      :publicly_available    => is_public,
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

    template.ext_management_system.should  == @ems
    template.operating_system.should       be_nil # TODO: This should probably not be nil
    template.custom_attributes.size.should == 0
    template.snapshots.size.should         == 0
    template.hardware.should               be_nil

    template.parent.should                 be_nil
    template
  end
end
