require "spec_helper"

describe EmsRefresh::MetadataRelats do
  context ".vmdb_relats" do
    before(:each) do
      @zone    = FactoryGirl.create(:zone)
      @ems     = FactoryGirl.create(:ems_vmware, :zone => @zone)
      @cluster = FactoryGirl.create(:ems_cluster,   :ext_management_system => @ems)
      @host    = FactoryGirl.create(:host,          :ext_management_system => @ems, :ems_cluster => @cluster)
      @vm      = FactoryGirl.create(:vm_vmware,     :ext_management_system => @ems, :ems_cluster => @cluster, :host => @host)

      @rp      = FactoryGirl.create(:resource_pool, :ext_management_system => @ems)
      @folder  = FactoryGirl.create(:ems_folder,    :ext_management_system => @ems)
      @folder.add_cluster(@cluster)
      @cluster.add_resource_pool(@rp)
      @rp.add_vm(@vm)

      [@ems, @folder, @cluster, @rp, @host, @vm].each(&:reload)
      MiqQueue.delete_all
    end

    it "with a Vm" do
      EmsRefresh.vmdb_relats(@vm).should == {
        :folders_to_clusters        => {@folder.id  => [@cluster.id]},
        :clusters_to_resource_pools => {@cluster.id => [@rp.id]},
        :resource_pools_to_vms      => {@rp.id      => [@vm.id]},
      }
    end

    it "with a Host" do
      EmsRefresh.vmdb_relats(@host).should == {
        :folders_to_clusters        => {@folder.id  => [@cluster.id]},
      }
    end

    it "with an EMS" do
      EmsRefresh.vmdb_relats(@ems).should == {
        :folders_to_clusters        => {@folder.id  => [@cluster.id]},
        :clusters_to_resource_pools => {@cluster.id => [@rp.id]},
        :resource_pools_to_vms      => {@rp.id      => [@vm.id]},
      }
    end

    context "with an invalid relats tree" do
      before(:each) do
        @rp2 = FactoryGirl.create(:resource_pool, :ext_management_system => @ems)
        @host.set_child(@rp2)
        @folder.add_host(@host)

        [@folder, @host, @rp2].each(&:reload)
        MiqQueue.delete_all
      end

      it "with an EMS" do
        EmsRefresh.vmdb_relats(@ems).should == {
          :folders_to_hosts           => {@folder.id  => [@host.id]},
          :folders_to_clusters        => {@folder.id  => [@cluster.id]},
          :clusters_to_resource_pools => {@cluster.id => [@rp.id]},
          :hosts_to_resource_pools    => {@host.id    => [@rp2.id]},
          :resource_pools_to_vms      => {@rp.id      => [@vm.id]},
        }
      end
    end
  end
end
