RSpec.describe ResourcePool do
  subject { FactoryBot.create(:resource_pool) }

  include_examples "MiqPolicyMixin"

  describe "AggregationMixin methods" do
    let(:host) { FactoryBot.create(:host, :storage) }
    let(:rp) { FactoryBot.create(:resource_pool) }
    let(:vm) { FactoryBot.create(:vm_vmware, :hardware => FactoryBot.create(:hardware, :cpu2x2, :memory_mb => 2048)) }
    let(:vm2) { FactoryBot.create(:vm_vmware, :hardware => FactoryBot.create(:hardware, :cpu2x2, :memory_mb => 1024)) }

    before do
      rp.with_relationship_type("ems_metadata") { rp.set_parent host }
      vm.with_relationship_type("ems_metadata") { vm.set_parent rp }
      vm2.with_relationship_type("ems_metadata") { vm2.set_parent rp }
    end

    it "aggregate_vm_memory" do
      expect(rp.aggregate_vm_memory).to eq(3072)
    end

    it "aggregate_vm_cpus" do
      expect(rp.aggregate_vm_cpus).to eq(4)
    end

    it "all_storages" do
      expect(rp.all_storages).to eq([Storage.first])
    end

    it "returns zero for nonexistent associations" do
      expect(rp.aggregate_cpu_total_cores).to eq(0)
    end
  end

  context "Testing VM count virtual columns" do
    before do
      @rp1 = FactoryBot.create(:resource_pool, :name => "RP 1")
      @rp2 = FactoryBot.create(:resource_pool, :name => "RP 2")
      @rp3 = FactoryBot.create(:resource_pool, :name => "RP 3")
      @rp4 = FactoryBot.create(:resource_pool, :name => "RP 4")
      @rp5 = FactoryBot.create(:resource_pool, :name => "RP 5")
      @rp6 = FactoryBot.create(:resource_pool, :name => "RP 6")
      @rp7 = FactoryBot.create(:resource_pool, :name => "RP 7")

      @rp2.with_relationship_type("ems_metadata") {  @rp2.set_parent @rp1 }
      @rp5.with_relationship_type("ems_metadata") {  @rp5.set_parent @rp4 }
      @rp6.with_relationship_type("ems_metadata") {  @rp6.set_parent @rp5 }

      5.times do |_i|
        vm = FactoryBot.create(:vm_vmware, :name => "Test VM Under RP1")
        vm.with_relationship_type("ems_metadata") { vm.set_parent @rp1 }
      end

      10.times do |_i|
        vm = FactoryBot.create(:vm_vmware, :name => "Test VM Under RP2")
        vm.with_relationship_type("ems_metadata") { vm.set_parent @rp2 }
      end

      15.times do |_i|
        vm = FactoryBot.create(:vm_vmware, :name => "Test VM Under RP3")
        vm.with_relationship_type("ems_metadata") { vm.set_parent @rp3 }
      end

      1.times do |_i|
        vm = FactoryBot.create(:vm_vmware, :name => "Test VM Under RP4")
        vm.with_relationship_type("ems_metadata") { vm.set_parent @rp4 }
      end

      # @rp5 has no child VMs

      2.times do |_i|
        vm = FactoryBot.create(:vm_vmware, :name => "Test VM Under RP6")
        vm.with_relationship_type("ems_metadata") { vm.set_parent @rp6 }
      end

      # @rp7 has no child VMs
    end

    it "should return the correct values for v_direct_vms and v_total_vms" do
      expect(@rp1.v_direct_vms).to eq(5)
      expect(@rp1.v_total_vms).to eq(15)
      expect(@rp1.total_vms).to eq(15)
      expect(@rp1.vms.size).to eq(5)
      expect(@rp1.vms_and_templates.size).to eq(5)
      expect(@rp1.miq_templates.size).to eq(0)

      expect(@rp2.v_direct_vms).to eq(10)
      expect(@rp2.v_total_vms).to eq(10)
      expect(@rp2.vms.size).to eq(10)
      expect(@rp2.vms_and_templates.size).to eq(10)
      expect(@rp2.miq_templates.size).to eq(0)

      expect(@rp3.v_direct_vms).to eq(15)
      expect(@rp3.v_total_vms).to eq(15)
      expect(@rp3.vms.size).to eq(15)
      expect(@rp3.vms_and_templates.size).to eq(15)
      expect(@rp3.miq_templates.size).to eq(0)

      expect(@rp4.v_direct_vms).to eq(1)
      expect(@rp4.v_total_vms).to eq(3)
      expect(@rp4.vms.size).to eq(1)
      expect(@rp4.vms_and_templates.size).to eq(1)
      expect(@rp4.miq_templates.size).to eq(0)

      expect(@rp5.v_direct_vms).to eq(0)
      expect(@rp5.v_total_vms).to eq(2)
      expect(@rp5.vms.size).to eq(0)
      expect(@rp5.vms_and_templates.size).to eq(0)
      expect(@rp5.miq_templates.size).to eq(0)

      expect(@rp6.v_direct_vms).to eq(2)
      expect(@rp6.v_total_vms).to eq(2)
      expect(@rp6.vms.size).to eq(2)
      expect(@rp6.vms_and_templates.size).to eq(2)
      expect(@rp6.miq_templates.size).to eq(0)

      expect(@rp7.v_direct_vms).to eq(0)
      expect(@rp7.v_total_vms).to eq(0)
      expect(@rp7.vms.size).to eq(0)
      expect(@rp7.vms_and_templates.size).to eq(0)
      expect(@rp7.miq_templates.size).to eq(0)
    end
  end

  context "#tenant_identity" do
    let(:admin)    { FactoryBot.create(:user_with_group, :userid => "admin") }
    let(:tenant)   { FactoryBot.create(:tenant) }
    let(:ems)      { FactoryBot.create(:ext_management_system, :tenant => tenant) }
    before         { admin }

    subject        { @rp.tenant_identity }

    it "has tenant from provider" do
      @rp = FactoryBot.create(:resource_pool, :ems_id => ems.id)

      expect(subject).to                eq(admin)
      expect(subject.current_group).to  eq(ems.tenant.default_miq_group)
      expect(subject.current_tenant).to eq(ems.tenant)
    end

    it "without a provider, has tenant from root tenant" do
      @rp = FactoryBot.create(:resource_pool)

      expect(subject).to                eq(admin)
      expect(subject.current_group).to  eq(Tenant.root_tenant.default_miq_group)
      expect(subject.current_tenant).to eq(Tenant.root_tenant)
    end
  end

  describe "all_hosts" do
    let(:resource_pool) { FactoryBot.create(:resource_pool) }
    let(:cluster) { FactoryBot.create(:ems_cluster) }
    let(:rel) { FactoryBot.create(:relationship, :resource_type => "EmsCluster", :resource_id => cluster.id) }

    it "doesn't call all_hosts on the cluster" do
      cluster.with_relationship_type("ems_metadata") { cluster.add_child resource_pool }

      expect(cluster).not_to receive(:all_hosts)

      resource_pool.all_hosts
    end
  end
end
