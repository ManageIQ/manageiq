require "spec_helper"

describe TreeBuilderVmsAndTemplates do
  before do
    ems     = FactoryGirl.create(:ems_vmware, :zone => FactoryGirl.create(:zone))
    folder  = FactoryGirl.create(:ems_folder, :ext_management_system => ems)
    subfolder1 = FactoryGirl.create(:ems_folder)
    subfolder2 = FactoryGirl.create(:ems_folder)
    subfolder3 = FactoryGirl.create(:datacenter)

    folder.with_relationship_type("ems_metadata") { folder.add_child(subfolder1) }
    folder.with_relationship_type("ems_metadata") { folder.add_child(subfolder2) }
    folder.with_relationship_type("ems_metadata") { folder.add_child(subfolder3) }

    @vandt_tree = TreeBuilderVmsAndTemplates.new(ems, {})
    @tree = {ems => {folder => {subfolder1 => {}, subfolder2 => {}, subfolder3 => {}}}}
  end

  context "#sort_tree" do
    it "making sure sort_tree was successful for mixed ems_folder types" do
      expect {@vandt_tree.send(:sort_tree, @tree)}.not_to raise_error
    end
  end
end
