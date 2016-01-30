describe Relationship do
  before(:each) do
    @rel = FactoryGirl.create(:relationship_vm_vmware)
  end

  context "#filtered?" do
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
end
