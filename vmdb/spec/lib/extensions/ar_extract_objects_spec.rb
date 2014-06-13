##

require "spec_helper"

describe "ArExtractObjects" do
  context "ArExtractObjectsTest" do
    before(:each) do
      vms = (0...2).collect { FactoryGirl.create(:vm_vmware) }
      @vm1, @vm2 = *vms
      @id1, @id2 = vms.collect(&:id)
    end

    context "calling extract_objects" do
      it "should extract single objects" do
        # Test ids
        Vm.extract_objects([@id1]).should == [@vm1]
        Vm.extract_objects(@id1).should == @vm1

        # Test objects
        Vm.extract_objects([@vm1]).should == [@vm1]
        Vm.extract_objects(@vm1).should == @vm1

        # Test invalid id
        Vm.extract_objects(@id2 + 1).should be_nil

        # Test nil
        Vm.extract_objects(nil).should be_nil
      end

      it "should extract multiple objects" do
        # Test list of ids
        Vm.extract_objects([@id1, @id2]).should have_same_elements([@vm1, @vm2])
        Vm.extract_objects(@id1, @id2).should have_same_elements([@vm1, @vm2])

        # Test list of objects
        Vm.extract_objects([@vm1, @vm2]).should have_same_elements([@vm1, @vm2])
        Vm.extract_objects(@vm1, @vm2).should have_same_elements([@vm1, @vm2])

        # Test invalid id
        Vm.extract_objects([@id1, @id2 + 1]).should == [@vm1]
        Vm.extract_objects(@id1, @id2 + 1).should == [@vm1]

        Vm.extract_objects([@id2 + 1, @id2 + 2]).should be_empty
        Vm.extract_objects(@id2 + 1, @id2 + 2).should be_empty
      end
    end

    context "calling extract_ids" do
      it "should extract single objects" do
        # Test ids
        Vm.extract_ids([@id1]).should == [@id1]
        Vm.extract_ids(@id1).should == @id1

        # Test objects
        Vm.extract_ids([@vm1]).should == [@id1]
        Vm.extract_ids(@vm1).should == @id1

        # Test invalid id
        Vm.extract_ids(@id2 + 1).should == @id2 + 1

        # Test nil
        Vm.extract_ids(nil).should be_nil
      end

      it "should extract multiple objects" do
        # Test list of ids
        Vm.extract_ids([@id1, @id2]).should have_same_elements([@id1, @id2])
        Vm.extract_ids(@id1, @id2).should have_same_elements([@id1, @id2])

        # Test list of objects
        Vm.extract_ids([@vm1, @vm2]).should have_same_elements([@id1, @id2])
        Vm.extract_ids(@vm1, @vm2).should have_same_elements([@id1, @id2])

        # Test invalid ids
        Vm.extract_ids([@id1, @id2 + 1]).should have_same_elements([@id1, @id2 + 1])
        Vm.extract_ids(@id1, @id2 + 1).should have_same_elements([@id1, @id2 + 1])

        Vm.extract_ids([@id2 + 1, @id2 + 2]).should have_same_elements([@id2 + 1, @id2 + 2])
        Vm.extract_ids(@id2 + 1, @id2 + 2).should have_same_elements([@id2 + 1, @id2 + 2])
      end
    end
  end
end
