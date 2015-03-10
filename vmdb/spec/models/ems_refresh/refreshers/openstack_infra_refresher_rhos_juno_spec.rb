
require "spec_helper"

describe EmsRefresh::Refreshers::OpenstackInfraRefresher do
  before(:each) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_openstack_infra, :zone => zone, :hostname => "192.0.2.1",
                              :ipaddress => "192.0.2.1", :port => 5000)
    @ems.update_authentication(
        :default => {:userid => "admin", :password => "3ddb6de300630a431ffae7f01104c9988ec4c89d"})
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
    EmsCluster.count.should                  == 0
    Host.count.should                        == 6
    OrchestrationStack.count.should          == 1
    OrchestrationStackParameter.count.should == 132
    ResourcePool.count.should                == 0
    Vm.count.should                          == 0
    VmOrTemplate.count.should                == 16
    CustomAttribute.count.should             == 0
    CustomizationSpec.count.should           == 0
    Disk.count.should                        == 0
    GuestDevice.count.should                 == 0
    Hardware.count.should                    == 6
    Lan.count.should                         == 0
    MiqScsiLun.count.should                  == 0
    MiqScsiTarget.count.should               == 0
    Network.count.should                     == 0
    OperatingSystem.count.should             == 6
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
    @ems.ems_clusters.size.should         == 0
    @ems.resource_pools.size.should       == 0
    @ems.storages.size.should             == 0
    @ems.hosts.size.should                == 6
    @ems.orchestration_stacks.size.should == 1
    @ems.vms_and_templates.size.should    == 16
    @ems.vms.size.should                  == 0
    @ems.miq_templates.size.should        == 16
    @ems.customization_specs.size.should  == 0
  end

  def assert_specific_host
    @host = HostOpenstackInfra.find_by_name('06c2fb5a-22ab-450f-bd83-9342f7b823e6 (Controller)')

    @host.should have_attributes(
      :ems_ref          => "06c2fb5a-22ab-450f-bd83-9342f7b823e6",
      :ems_ref_obj      => "5de454a1-7f3c-418e-815d-0350aef47934",
      :name             => "06c2fb5a-22ab-450f-bd83-9342f7b823e6 (Controller)",
      :ipaddress        => "192.0.2.8",
      :mac_address      => "00:6b:a4:4c:df:f3",
      :ipmi_address     => nil,
      :vmm_vendor       => "RedHat",
      :vmm_version      => nil,
      :vmm_product      => "rhel (No hypervisor, Host Type is Controller)",
      :power_state      => "on",
      :connection_state => "connected"
    )

    @host.operating_system.should have_attributes(
      :product_name     => "linux"
    )

    @host.hardware.should have_attributes(
      :cpu_speed          => nil,
      :cpu_type           => nil,
      :manufacturer       => "",
      :model              => "",
      :memory_cpu         => 4096,  # MB
      :memory_console     => nil,
      :disk_capacity      => 40,
      :numvcpus           => 1,
      :logical_cpus       => nil,
      :cores_per_socket   => nil,
      :guest_os           => nil,
      :guest_os_full_name => nil,
      :cpu_usage          => nil,
      :memory_usage       => nil
    )
  end

  def assert_specific_public_template
    assert_specific_template("overcloud-control", "1734551c-dff7-472c-9925-f713e7af5a52", true)
  end

  def assert_specific_template(name, uid, is_public = false)
    template = TemplateOpenstack.where(:name => name).first
    template.should have_attributes(
      :template              => true,
      :publicly_available    => is_public,
      :ems_ref_obj           => nil,
      :uid_ems               => uid,
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
