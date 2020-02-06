RSpec.describe Relationship do
  describe "#filtered?" do
    before do
      @rel = FactoryBot.build(:relationship_vm_vmware)
    end

    it "with neither" do
      expect(@rel).not_to be_filtered([], [])
    end

    it "with of_type" do
      expect(@rel).not_to be_filtered(["VmOrTemplate"], [])
      expect(@rel).not_to be_filtered(["VmOrTemplate", "Host"], [])
      expect(@rel).not_to be_filtered(["Host", "VmOrTemplate"], [])
      expect(@rel).to     be_filtered(["Host"], [])
    end

    it "with except_type" do
      expect(@rel).to     be_filtered([], ["VmOrTemplate"])
      expect(@rel).to     be_filtered([], ["VmOrTemplate", "Host"])
      expect(@rel).to     be_filtered([], ["Host", "VmOrTemplate"])
      expect(@rel).not_to be_filtered([], ["Host"])
    end

    it "with both of_type and except_type" do
      expect(@rel).not_to be_filtered(["VmOrTemplate"], ["Host"])
      expect(@rel).to     be_filtered(["Host"], ["VmOrTemplate"])
    end
  end

  describe ".filter_by_resource_type" do
    let(:storages) { FactoryBot.build_list(:relationship_storage_vmware, 1) }
    let(:vms) { FactoryBot.build_list(:relationship_vm_vmware, 1) }
    let(:hosts) { FactoryBot.build_list(:relationship_host_vmware, 1) }

    it "includes" do
      expect(Relationship.filter_by_resource_type(vms + hosts, :of_type => "Host")).to eq(hosts)
      expect(Relationship.filter_by_resource_type(vms + hosts, :of_type => ["Host"])).to eq(hosts)
      expect(Relationship.filter_by_resource_type(vms + hosts, :of_type => ["Host"], :except_type => [])).to eq(hosts)
    end

    it "includes multi" do
      expect(Relationship.filter_by_resource_type(vms + hosts + storages, :of_type => %w(Host VmOrTemplate)))
        .to match_array(vms + hosts)
    end

    it "includes everything" do
      expect(Relationship.filter_by_resource_type(vms + hosts, :of_type => %w(Host VmOrTemplate))).to eq(vms + hosts)
    end

    it "includes nothing" do
      expect(Relationship.filter_by_resource_type(vms, :of_type => ["Host"])).to be_empty
    end

    it "excludes" do
      expect(Relationship.filter_by_resource_type(vms + hosts, :except_type => "Host")).to eq(vms)
      expect(Relationship.filter_by_resource_type(vms + hosts, :except_type => ["Host"])).to eq(vms)
      expect(Relationship.filter_by_resource_type(vms + hosts, :except_type => ["Host"], :of_type => [])).to eq(vms)
    end

    it "excludes multi" do
      expect(Relationship.filter_by_resource_type(vms + hosts + storages, :except_type => %w(Host VmOrTemplate)))
        .to eq(storages)
    end

    it "excludes everything" do
      expect(Relationship.filter_by_resource_type(vms + hosts, :except_type => %w(Host VmOrTemplate))).to be_empty
    end

    it "excludes nothing" do
      expect(Relationship.filter_by_resource_type(vms, :except_type => %w(Host))).to eq(vms)
    end

    it "includes and excludes" do
      expect(Relationship.filter_by_resource_type(vms + hosts, :of_type => ["VmOrTemplate"], :except_type => ["Host"]))
        .to eq(vms)
    end

    it "neither includes nor excludes" do
      expect(Relationship.filter_by_resource_type(vms, {})).to eq(vms)
    end

    it "scopes" do
      vms.map(&:save!)
      hosts.map(&:save!)
      storages.map(&:save!)
      filtered_results = Relationship.filter_by_resource_type(Relationship.all,
                                                              :of_type     => %w(Host VmOrTemplate),
                                                              :except_type => %w(Storage))
      expect(filtered_results).not_to be_kind_of(Array)
      expect(filtered_results).to match_array(vms + hosts)
    end

    it "uses preloaded data" do
      vms.map(&:save!)
      hosts.map(&:save!)
      storages.map(&:save!)
      rels = Relationship.all.load
      filtered_results = Relationship.filter_by_resource_type(rels,
                                                              :of_type     => %w(Host VmOrTemplate),
                                                              :except_type => %w(Storage))
      expect(filtered_results).to be_kind_of(Array)
    end
  end

  describe ".filtered" do
    let(:storages) { FactoryBot.build_list(:relationship_storage_vmware, 1) }
    let(:vms) { FactoryBot.build_list(:relationship_vm_vmware, 1) }
    let(:hosts) { FactoryBot.build_list(:relationship_host_vmware, 1) }

    it "scopes" do
      vms.map(&:save!)
      hosts.map(&:save!)
      storages.map(&:save!)
      filtered_results = Relationship.filtered(%w(Host VmOrTemplate), %w(Storage))
      expect(filtered_results).to match_array(vms + hosts)
    end
  end
end
