RSpec.describe EmsRefresh::MetadataRelats do
  context ".vmdb_relats" do
    before do
      @zone        = FactoryBot.create(:zone)
      @ems         = FactoryBot.create(:ems_vmware, :zone => @zone)

      @cluster     = FactoryBot.create(:ems_cluster,        :ext_management_system => @ems)
      @host        = FactoryBot.create(:host,               :ext_management_system => @ems, :ems_cluster => @cluster)
      @vm          = FactoryBot.create(:vm_vmware,          :ext_management_system => @ems, :ems_cluster => @cluster, :host => @host)
      @template    = FactoryBot.create(:template_vmware,    :ext_management_system => @ems)
      @rp          = FactoryBot.create(:resource_pool,      :ext_management_system => @ems)
      @host_folder = FactoryBot.create(:vmware_folder_host, :ext_management_system => @ems)
      @vm_folder_1 = FactoryBot.create(:vmware_folder_vm,   :ext_management_system => @ems, :name => "folder1")
      @vm_folder_2 = FactoryBot.create(:vmware_folder_vm,   :ext_management_system => @ems, :name => "folder2")

      @host_folder.add_cluster(@cluster)
      @cluster.add_resource_pool(@rp)
      @rp.add_vm(@vm)

      @vm_folder_1.add_vm(@vm)
      @vm_folder_2.add_vm(@template)

      [@ems, @host_folder, @vm_folder_1, @vm_folder_2, @cluster, @rp, @host, @vm, @template].each(&:reload)
      MiqQueue.delete_all
    end

    it "with a Vm" do
      expect(EmsRefresh.vmdb_relats(@vm)).to eq(:folders_to_clusters        => {@host_folder.id  => [@cluster.id]},
                                                :folders_to_vms             => {@vm_folder_1.id  => [@vm.id]},
                                                :clusters_to_resource_pools => {@cluster.id      => [@rp.id]},
                                                :resource_pools_to_vms      => {@rp.id           => [@vm.id]})
    end

    it "with a Host" do
      expect(EmsRefresh.vmdb_relats(@host)).to eq(:folders_to_clusters => {@host_folder.id => [@cluster.id]})
    end

    it "with an EMS" do
      expect(EmsRefresh.vmdb_relats(@ems)).to eq(:folders_to_clusters        => {@host_folder.id  => [@cluster.id]},
                                                 :folders_to_vms             => {@vm_folder_1.id  => [@vm.id],
                                                                                 @vm_folder_2.id  => [@template.id]},
                                                 :clusters_to_resource_pools => {@cluster.id      => [@rp.id]},
                                                 :resource_pools_to_vms      => {@rp.id           => [@vm.id]})
    end

    context "with an invalid relats tree" do
      before do
        @rp2 = FactoryBot.create(:resource_pool, :ext_management_system => @ems)
        @host.set_child(@rp2)
        @host_folder.add_host(@host)

        [@host_folder, @host, @rp2].each(&:reload)
        MiqQueue.delete_all
      end

      it "with an EMS" do
        expect(EmsRefresh.vmdb_relats(@ems)).to eq(:folders_to_hosts           => {@host_folder.id  => [@host.id]},
                                                   :folders_to_vms             => {@vm_folder_1.id  => [@vm.id],
                                                                                   @vm_folder_2.id  => [@template.id]},
                                                   :folders_to_clusters        => {@host_folder.id  => [@cluster.id]},
                                                   :clusters_to_resource_pools => {@cluster.id => [@rp.id]},
                                                   :hosts_to_resource_pools    => {@host.id    => [@rp2.id]},
                                                   :resource_pools_to_vms      => {@rp.id      => [@vm.id]})
      end
    end
  end
end
