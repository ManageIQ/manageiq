
require "spec_helper"

describe EmsRefresh::Refreshers::OpenstackInfraRefresher do
  before(:each) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_openstack_infra, :zone => zone, :hostname => "192.0.2.1",
                              :ipaddress => "192.0.2.1", :port => 5000)
    @ems.update_authentication(
        :default => {:userid => "admin", :password => "a280e99820b2e01a42acc9535c81234842b45471"})

    mock_object = double
    mock_object.stub(:shell_exec).with("lscpu").and_return("Architecture:          x86_64\nCPU op-mode(s):        32-bit, 64-bit\nByte Order:            Little Endian\nCPU(s):                1\nOn-line CPU(s) list:   0\nThread(s) per core:    1\nCore(s) per socket:    1\nSocket(s):             1\nNUMA node(s):          1\nVendor ID:             GenuineIntel\nCPU family:            6\nModel:                 13\nModel name:            QEMU Virtual CPU version 2.1.2\nStepping:              3\nCPU MHz:               2399.998\nBogoMIPS:              4799.99\nHypervisor vendor:     KVM\nVirtualization type:   full\nL1d cache:             32K\nL1i cache:             32K\nL2 cache:              4096K\nNUMA node0 CPU(s):     0\n")
    mock_object.stub(:shell_exec).with("dmidecode | grep -A8 'System Information'").and_return("System Information\n\tManufacturer: Red Hat\n\tProduct Name: KVM\n\tVersion: RHEL 7.1.0 PC (i440FX + PIIX, 1996)\n\tSerial Number: Not Specified\n\tUUID: 32B5BB93-364E-4D7D-A77C-CCBA193DB50B\n\tWake-up Type: Power Switch\n\tSKU Number: Not Specified\n\tFamily: Red Hat Enterprise Linux\n")
    HostOpenstackInfra.any_instance.stub(:connect_ssh).and_yield(mock_object)
    HostOpenstackInfra.any_instance.stub(:refreshable_via_ssh?).and_return(true)
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
    Host.count.should                        == 4
    OrchestrationStack.count.should          == 1
    OrchestrationStackParameter.count.should == 130
    OrchestrationStackResource.count.should  == 62
    OrchestrationStackOutput.count.should    == 1
    OrchestrationTemplate.count.should       == 1
    ResourcePool.count.should                == 0
    Vm.count.should                          == 0
    VmOrTemplate.count.should                == 16
    CustomAttribute.count.should             == 0
    CustomizationSpec.count.should           == 0
    Disk.count.should                        == 0
    GuestDevice.count.should                 == 0
    Hardware.count.should                    == 4
    Lan.count.should                         == 0
    MiqScsiLun.count.should                  == 0
    MiqScsiTarget.count.should               == 0
    Network.count.should                     == 0
    OperatingSystem.count.should             == 4
    Snapshot.count.should                    == 0
    Switch.count.should                      == 0
    SystemService.count.should               == 0
    Relationship.count.should                == 0
    MiqQueue.count.should                    == 19
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
    @ems.hosts.size.should                == 4
    @ems.orchestration_stacks.size.should == 1
    @ems.vms_and_templates.size.should    == 16
    @ems.vms.size.should                  == 0
    @ems.miq_templates.size.should        == 16
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
      :vmm_version      => "RHEL 7.1.0 PC (i440FX + PIIX, 1996)",
      :vmm_product      => "rhel (No hypervisor, Host Type is Controller)",
      :power_state      => "on",
      :connection_state => "connected",
      :service_tag      => "Not Specified"
    )

    @host.operating_system.should have_attributes(
      :product_name     => "linux"
    )

    @host.hardware.should have_attributes(
      :cpu_speed          => 2399,
      :cpu_type           => "QEMU Virtual CPU version 2.1.2",
      :manufacturer       => "Red Hat",
      :model              => "KVM",
      :memory_cpu         => 4096,  # MB
      :memory_console     => nil,
      :disk_capacity      => 40,
      :numvcpus           => 1,
      :logical_cpus       => 1,
      :cores_per_socket   => 1,
      :guest_os           => "Red Hat Enterprise Linux",
      :guest_os_full_name => "RHEL 7.1.0 PC (i440FX + PIIX, 1996)",
      :cpu_usage          => nil,
      :memory_usage       => nil,
    )
  end

  def assert_specific_public_template
    assert_specific_template("overcloud-control", true)
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
