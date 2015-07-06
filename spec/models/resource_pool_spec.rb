require "spec_helper"


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

      5.times do |i|
        vm = FactoryGirl.create(:vm_vmware, :name => "Test VM Under RP1")
        vm.with_relationship_type("ems_metadata") { vm.set_parent @rp1 }
      end

      10.times do |i|
        vm = FactoryGirl.create(:vm_vmware, :name => "Test VM Under RP2")
        vm.with_relationship_type("ems_metadata") { vm.set_parent @rp2 }
      end

      15.times do |i|
        vm = FactoryGirl.create(:vm_vmware, :name => "Test VM Under RP3")
        vm.with_relationship_type("ems_metadata") { vm.set_parent @rp3 }
      end

      1.times do |i|
        vm = FactoryGirl.create(:vm_vmware, :name => "Test VM Under RP4")
        vm.with_relationship_type("ems_metadata") { vm.set_parent @rp4 }
      end

      # @rp5 has no child VMs

      2.times do |i|
        vm = FactoryGirl.create(:vm_vmware, :name => "Test VM Under RP6")
        vm.with_relationship_type("ems_metadata") { vm.set_parent @rp6 }
      end

      # @rp7 has no child VMs
    end

    it "should return the correct values for v_direct_vms and v_total_vms" do
      @rp1.v_direct_vms.should == 5
      @rp1.v_total_vms.should  == 15

      @rp2.v_direct_vms.should == 10
      @rp2.v_total_vms.should  == 10

      @rp3.v_direct_vms.should == 15
      @rp3.v_total_vms.should  == 15

      @rp4.v_direct_vms.should == 1
      @rp4.v_total_vms.should  == 3

      @rp5.v_direct_vms.should == 0
      @rp5.v_total_vms.should  == 2

      @rp6.v_direct_vms.should == 2
      @rp6.v_total_vms.should  == 2

      @rp7.v_direct_vms.should == 0
      @rp7.v_total_vms.should  == 0
    end
  end
end
