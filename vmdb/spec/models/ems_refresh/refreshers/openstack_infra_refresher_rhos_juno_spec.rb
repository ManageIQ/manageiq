
require "spec_helper"

describe EmsRefresh::Refreshers::OpenstackInfraRefresher do
  before(:each) do
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    @ems = FactoryGirl.create(:ems_openstack_infra, :zone => zone, :hostname => "192.0.2.1",
                              :ipaddress => "192.0.2.1", :port => 5000)
    @ems.update_authentication(
        :default => {:userid => "admin", :password => "22ffdb40bb99703b3650a79c1c1305a65d83e898"})
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
    end
  end

  def assert_table_counts
    ExtManagementSystem.count.should == 1
    EmsFolder.count.should           == 0 # HACK: Folder structure for UI a la VMware
    EmsCluster.count.should          == 0
    Host.count.should                == 7
    ResourcePool.count.should        == 0
    Vm.count.should                  == 0
    VmOrTemplate.count.should        == 0
    CustomAttribute.count.should     == 0
    CustomizationSpec.count.should   == 0
    Disk.count.should                == 0
    GuestDevice.count.should         == 0
    Hardware.count.should            == 7
    Lan.count.should                 == 0
    MiqScsiLun.count.should          == 0
    MiqScsiTarget.count.should       == 0
    Network.count.should             == 0
    OperatingSystem.count.should     == 0
    Snapshot.count.should            == 0
    Switch.count.should              == 0
    SystemService.count.should       == 0
    Relationship.count.should        == 0

    MiqQueue.count.should            == 3
    Storage.count.should             == 0
  end

  def assert_ems
    @ems.should have_attributes(
      :api_version => nil,
      :uid_ems     => nil
    )
    @ems.ems_folders.size.should         == 0 # HACK: Folder structure for UI a la VMware
    @ems.ems_clusters.size.should        == 0
    @ems.resource_pools.size.should      == 0

    @ems.storages.size.should            == 0
    @ems.hosts.size.should               == 7
    @ems.vms_and_templates.size.should   == 0
    @ems.vms.size.should                 == 0
    @ems.miq_templates.size.should       == 0
    @ems.customization_specs.size.should == 0
  end

  def assert_specific_host
    @host = HostOpenstackInfra.find_by_name('d783b2e4-059e-4e2b-a1d1-21b3d1a7dab6')
    @host.should have_attributes(
      :ems_ref          => "d783b2e4-059e-4e2b-a1d1-21b3d1a7dab6",
      :ems_ref_obj      => "492b83e2-1805-4022-a385-876230ce5d43",
      :name             => "d783b2e4-059e-4e2b-a1d1-21b3d1a7dab6",
      :hostname         => nil,
      :ipaddress        => "192.0.2.8",
      :mac_address      => "00:22:a4:80:56:c7",
      :ipmi_address     => nil,
      :vmm_vendor       => "Unknown",
      :vmm_version      => nil,
      :vmm_product      => nil,
      :power_state      => "on",
      :connection_state => nil
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
end
