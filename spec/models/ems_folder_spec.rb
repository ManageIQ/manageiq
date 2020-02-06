RSpec.describe EmsFolder do
  context "with folder tree" do
    before do
      @root = FactoryBot.create(:ems_folder, :name => "root")

      @dc   = FactoryBot.create(:datacenter, :name => "dc")
      @dc.parent = @root

      @vm = FactoryBot.create(:ems_folder, :name => "vm", :hidden => true)
      @vm.parent = @dc

      @host = FactoryBot.create(:ems_folder, :name => "host", :hidden => true)
      @host.parent = @dc

      @sib1 = FactoryBot.create(:ems_folder, :name => "sib1")
      @sib1.parent = @vm

      @sib2 = FactoryBot.create(:ems_folder, :name => "sib2")
      @sib2.parent = @vm

      @leaf = FactoryBot.create(:ems_folder, :name => "leaf")
      @leaf.parent = @sib2

      @yellow = FactoryBot.create(:ems_folder, :name => "prod_cluster")
      @yellow.parent = @host
    end

    it "calling child_folder_paths" do
      expected = {
        @root.id   => "root",
        @dc.id     => "root/dc",
        @vm.id     => "root/dc/vm",
        @host.id   => "root/dc/host",
        @sib1.id   => "root/dc/vm/sib1",
        @sib2.id   => "root/dc/vm/sib2",
        @leaf.id   => "root/dc/vm/sib2/leaf",
        @yellow.id => "root/dc/host/prod_cluster"
      }
      expect(@root.child_folder_paths).to eq(expected)
    end

    context "#vm_folder?" do
      it "returns false for a yellow folder" do
        expect(@yellow.vm_folder?).to be_falsy
      end

      it "returns false for the hidden host folder" do
        expect(@host.vm_folder?).to be_falsy
      end

      it "returns false for the datacenter" do
        expect(@dc.vm_folder?).to be_falsy
      end

      it "return false for folders above the datacenter" do
        expect(@root.vm_folder?).to be_falsy
      end

      it "returns true for the hidden vm folder" do
        expect(@vm.vm_folder?).to be_truthy
      end

      it "returns true for a child folder of the vm folder" do
        expect(@sib1.vm_folder?).to be_truthy
      end

      it "returns true for a leaf folder of the vm folder" do
        expect(@leaf.vm_folder?).to be_truthy
      end
    end
  end
end
