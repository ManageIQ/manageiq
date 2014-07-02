require "spec_helper"

describe EmsFolder do
  context "#hidden?" do
    it "when not VMware" do
      folder = FactoryGirl.build(:ems_folder, :name => "vm",
        :ext_management_system => FactoryGirl.build(:ems_openstack)
      )
      expect(folder).to_not be_hidden
    end

    context "when VMware" do
      let(:ems) { FactoryGirl.build(:ems_vmware) }

      context "and named Datacenters" do
        let(:folder) { FactoryGirl.create(:ems_folder, :name => "Datacenters", :ext_management_system => ems) }

        it "and parent is the EMS" do
          folder.parent = ems
          expect(folder).to be_hidden
        end

        it "and parent is not the EMS" do
          folder.parent = FactoryGirl.create(:ems_folder)
          expect(folder).to_not be_hidden
        end
      end

      ["vm", "host"].each do |name|
        context "and named #{name}" do
          let(:folder) { FactoryGirl.create(:ems_folder, :name => name, :ext_management_system => ems) }

          it "and parent is a datacenter" do
            folder.parent = FactoryGirl.create(:datacenter)
            expect(folder).to be_hidden
          end

          it "and parent is not a datacenter" do
            folder.parent = FactoryGirl.create(:ems_folder)
            expect(folder).to_not be_hidden
          end
        end
      end

      it "and not named with a hidden name" do
        folder = FactoryGirl.build(:ems_folder, :ext_management_system => ems)
        expect(folder).to_not be_hidden
      end
    end
  end

  context "with folder tree" do
    before(:each) do
      @root = FactoryGirl.create(:ems_folder, :name => "root")

      @dc   = FactoryGirl.create(:ems_folder, :name => "dc")
      @dc.parent = @root

      @sib1 = FactoryGirl.create(:ems_folder, :name => "sib1")
      @sib1.parent = @dc

      @sib2 = FactoryGirl.create(:ems_folder, :name => "sib2")
      @sib2.parent = @dc

      @leaf = FactoryGirl.create(:ems_folder, :name => "leaf")
      @leaf.parent = @sib2
    end

    it "calling child_folder_paths" do
      expected = {
        @root.id => "root",
        @dc.id   => "root/dc",
        @sib1.id => "root/dc/sib1",
        @sib2.id => "root/dc/sib2",
        @leaf.id => "root/dc/sib2/leaf"
      }
      @root.child_folder_paths.should == expected
    end
  end
end
