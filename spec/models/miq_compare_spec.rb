describe MiqCompare do
  context "Marshal.dump and Marshal.load" do
    it "with Vms" do
      vm1 = FactoryGirl.create(:vm_vmware)
      vm2 = FactoryGirl.create(:vm_vmware)

      MiqReport.seed_report("vms", "compare")

      report = MiqReport.find_by(:name => "VMs: Compare Template")
      compare = MiqCompare.new({:ids => [vm1.id, vm2.id]}, report)

      dumped = loaded = nil
      expect { dumped = Marshal.dump(compare) }.not_to raise_error
      expect { loaded = Marshal.load(dumped)  }.not_to raise_error
    end

    it "with Hosts" do
      host1 = FactoryGirl.create(:host_vmware)
      host2 = FactoryGirl.create(:host_vmware)

      MiqRegion.seed
      MiqReport.seed_report("hosts", "compare")

      report = MiqReport.find_by(:name => "Hosts: Compare Template")
      compare = MiqCompare.new({:ids => [host1.id, host2.id]}, report)

      dumped = loaded = nil
      expect { dumped = Marshal.dump(compare) }.not_to raise_error
      expect { loaded = Marshal.load(dumped)  }.not_to raise_error
    end
  end
end
