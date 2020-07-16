RSpec.describe MiqCompare do
  context "Marshal.dump and Marshal.load" do
    it "with Vms" do
      vm1 = FactoryBot.create(:vm_vmware)
      vm2 = FactoryBot.create(:vm_vmware)

      MiqReport.seed_report("vms")

      report = MiqReport.find_by(:name => "VMs: Compare Template")
      compare = MiqCompare.new({:ids => [vm1.id, vm2.id]}, report)

      dumped = loaded = nil
      expect { dumped = Marshal.dump(compare) }.not_to raise_error
      expect { loaded = Marshal.load(dumped)  }.not_to raise_error
    end

    it "with Hosts" do
      host1 = FactoryBot.create(:host_vmware)
      host2 = FactoryBot.create(:host_vmware)

      MiqRegion.seed
      MiqReport.seed_report("hosts")

      report = MiqReport.find_by(:name => "Hosts: Compare Template")
      compare = MiqCompare.new({:ids => [host1.id, host2.id]}, report)

      dumped = loaded = nil
      expect { dumped = Marshal.dump(compare) }.not_to raise_error
      expect { loaded = Marshal.load(dumped)  }.not_to raise_error
    end
  end

  context "headers are translated" do
    it "for EmsCluster" do
      skip "Assumptions based on English message catalog" unless FastGettext.locale == "en"

      obj1 = FactoryBot.create(:ems_cluster)
      obj2 = FactoryBot.create(:ems_cluster)
      MiqReport.seed_report("clusters")
      report = MiqReport.find_by(:title => "Cluster Compare Template")
      compare = MiqCompare.new({:ids => [obj1.id, obj2.id]}, report)
      expect(compare.master_list[0][:header]).to eq("Cluster")
    end

    it "for Host" do
      skip "Assumptions based on English message catalog" unless FastGettext.locale == "en"

      obj1 = FactoryBot.create(:host_vmware)
      obj2 = FactoryBot.create(:host_vmware)
      MiqReport.seed_report("hosts")
      report = MiqReport.find_by(:name => "Hosts: Compare Template")
      compare = MiqCompare.new({:ids => [obj1.id, obj2.id]}, report)
      expect(compare.master_list[0][:header]).to eq("Host Properties")
    end
  end
end
