describe ResourcePool do
  context "Testing VM count virtual columns" do
    before(:each) do
      @rp1 = FactoryGirl.create(:resource_pool, :name => "RP 1")
      @rp2 = FactoryGirl.create(:resource_pool, :name => "RP 2")
      @rp3 = FactoryGirl.create(:resource_pool, :name => "RP 3")
      @rp4 = FactoryGirl.create(:resource_pool, :name => "RP 4")
      @rp5 = FactoryGirl.create(:resource_pool, :name => "RP 5")
      @rp6 = FactoryGirl.create(:resource_pool, :name => "RP 6")
      @rp7 = FactoryGirl.create(:resource_pool, :name => "RP 7")

      @rp2.with_relationship_type("ems_metadata") {  @rp2.set_parent @rp1 }
      @rp5.with_relationship_type("ems_metadata") {  @rp5.set_parent @rp4 }
      @rp6.with_relationship_type("ems_metadata") {  @rp6.set_parent @rp5 }

      5.times do |_i|
        vm = FactoryGirl.create(:vm_vmware, :name => "Test VM Under RP1")
        vm.with_relationship_type("ems_metadata") { vm.set_parent @rp1 }
      end

      10.times do |_i|
        vm = FactoryGirl.create(:vm_vmware, :name => "Test VM Under RP2")
        vm.with_relationship_type("ems_metadata") { vm.set_parent @rp2 }
      end

      15.times do |_i|
        vm = FactoryGirl.create(:vm_vmware, :name => "Test VM Under RP3")
        vm.with_relationship_type("ems_metadata") { vm.set_parent @rp3 }
      end

      1.times do |_i|
        vm = FactoryGirl.create(:vm_vmware, :name => "Test VM Under RP4")
        vm.with_relationship_type("ems_metadata") { vm.set_parent @rp4 }
      end

      # @rp5 has no child VMs

      2.times do |_i|
        vm = FactoryGirl.create(:vm_vmware, :name => "Test VM Under RP6")
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
    let(:admin)    { FactoryGirl.create(:user_with_group, :userid => "admin") }
    let(:tenant)   { FactoryGirl.create(:tenant) }
    let(:ems)      { FactoryGirl.create(:ext_management_system, :tenant => tenant) }
    before         { admin }

    subject        { @rp.tenant_identity }

    it "has tenant from provider" do
      @rp = FactoryGirl.create(:resource_pool, :ems_id => ems.id)

      expect(subject).to                eq(admin)
      expect(subject.current_group).to  eq(ems.tenant.default_miq_group)
      expect(subject.current_tenant).to eq(ems.tenant)
    end

    it "without a provider, has tenant from root tenant" do
      @rp = FactoryGirl.create(:resource_pool)

      expect(subject).to                eq(admin)
      expect(subject.current_group).to  eq(Tenant.root_tenant.default_miq_group)
      expect(subject.current_tenant).to eq(Tenant.root_tenant)
    end
  end
end
