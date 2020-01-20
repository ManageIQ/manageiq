RSpec.describe "ArExtractObjects" do
  context "ArExtractObjectsTest" do
    before do
      vms = (0...2).collect { FactoryBot.create(:vm_vmware) }
      @vm1, @vm2 = *vms
      @id1, @id2 = vms.collect(&:id)
    end

    context "calling extract_objects" do
      it "should extract single objects" do
        # Test ids
        expect(Vm.extract_objects([@id1])).to eq([@vm1])
        expect(Vm.extract_objects(@id1)).to eq(@vm1)

        # Test objects
        expect(Vm.extract_objects([@vm1])).to eq([@vm1])
        expect(Vm.extract_objects(@vm1)).to eq(@vm1)

        # Test invalid id
        expect(Vm.extract_objects(@id2 + 1)).to be_nil

        # Test nil
        expect(Vm.extract_objects(nil)).to be_nil
      end

      it "should extract multiple objects" do
        # Test list of ids
        expect(Vm.extract_objects([@id1, @id2])).to match_array([@vm1, @vm2])
        expect(Vm.extract_objects(@id1, @id2)).to match_array([@vm1, @vm2])

        # Test list of objects
        expect(Vm.extract_objects([@vm1, @vm2])).to match_array([@vm1, @vm2])
        expect(Vm.extract_objects(@vm1, @vm2)).to match_array([@vm1, @vm2])

        # Test invalid id
        expect(Vm.extract_objects([@id1, @id2 + 1])).to eq([@vm1])
        expect(Vm.extract_objects(@id1, @id2 + 1)).to eq([@vm1])

        expect(Vm.extract_objects([@id2 + 1, @id2 + 2])).to be_empty
        expect(Vm.extract_objects(@id2 + 1, @id2 + 2)).to be_empty
      end
    end

    context "calling extract_ids" do
      it "should extract single objects" do
        # Test ids
        expect(Vm.extract_ids([@id1])).to eq([@id1])
        expect(Vm.extract_ids(@id1)).to eq(@id1)

        # Test objects
        expect(Vm.extract_ids([@vm1])).to eq([@id1])
        expect(Vm.extract_ids(@vm1)).to eq(@id1)

        # Test invalid id
        expect(Vm.extract_ids(@id2 + 1)).to eq(@id2 + 1)

        # Test nil
        expect(Vm.extract_ids(nil)).to be_nil
      end

      it "should extract multiple objects" do
        # Test list of ids
        expect(Vm.extract_ids([@id1, @id2])).to match_array([@id1, @id2])
        expect(Vm.extract_ids(@id1, @id2)).to match_array([@id1, @id2])

        # Test list of objects
        expect(Vm.extract_ids([@vm1, @vm2])).to match_array([@id1, @id2])
        expect(Vm.extract_ids(@vm1, @vm2)).to match_array([@id1, @id2])

        # Test invalid ids
        expect(Vm.extract_ids([@id1, @id2 + 1])).to match_array([@id1, @id2 + 1])
        expect(Vm.extract_ids(@id1, @id2 + 1)).to match_array([@id1, @id2 + 1])

        expect(Vm.extract_ids([@id2 + 1, @id2 + 2])).to match_array([@id2 + 1, @id2 + 2])
        expect(Vm.extract_ids(@id2 + 1, @id2 + 2)).to match_array([@id2 + 1, @id2 + 2])
      end
    end
  end
end
