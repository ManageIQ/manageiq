require_relative "refresh_spec_common"

describe ManageIQ::Providers::Openstack::CloudManager::Refresher do
  include Openstack::RefreshSpecCommon

  before(:each) do
    setup_ems('11.22.33.44', 'password_2WpEraURh')
    @environment = :juno
  end

  it "will perform a full refresh against RHOS #{@environment}" do
    2.times do # Run twice to verify that a second run with existing data does not change anything
      with_cassette(@environment, @ems) do
        EmsRefresh.refresh(@ems)
        EmsRefresh.refresh(@ems.network_manager)
      end

      assert_common
    end
  end

  context "when configured with skips" do
    before(:each) do
      stub_settings(
        :ems_refresh => {:openstack => {:inventory_ignore => [:cloud_volumes, :cloud_volume_snapshots]}}
      )
    end

    it "will not parse the ignored items" do
      with_cassette(@environment, @ems) do
        EmsRefresh.refresh(@ems)
        EmsRefresh.refresh(@ems.network_manager)
      end

      assert_with_skips
    end
  end

  context "when paired with a infrastructure provider" do
    # assumes all cloud instances are on single host => dhcp-8-99-240.cloudforms.lab.eng.rdu2.redhat.com
    before(:each) do
      @cpu_speed = 2800
      @hardware = FactoryGirl.create(:hardware, :cpu_speed => @cpu_speed, :cpu_sockets => 2, :cpu_cores_per_socket => 4, :cpu_total_cores => 8)
      @infra_host = FactoryGirl.create(:host_openstack_infra, :hardware => @hardware, :hypervisor_hostname => "dhcp-8-99-240.cloudforms.lab.eng.rdu2.redhat.com")
      @provider = FactoryGirl.create(:provider_openstack, :name => "undercloud")
      @infra = FactoryGirl.create(:ems_openstack_infra_with_stack, :name => "undercloud", :provider => @provider)
      @infra.hosts << @infra_host
      @ems.provider = @provider
      @provider.infra_ems = @infra
      @provider.cloud_ems << @ems
    end

    it "user instance should inherit cpu_speed of compute host" do
      with_cassette(@environment, @ems) do
        EmsRefresh.refresh(@ems)
        EmsRefresh.refresh(@ems.network_manager)
      end

      ManageIQ::Providers::Openstack::CloudManager::Vm.all.each do |vm|
        expect(vm.hardware.cpu_speed).to eq(@cpu_speed) if vm.name !='EmsRefreshSpec-Shelved'
      end
    end
  end
end
