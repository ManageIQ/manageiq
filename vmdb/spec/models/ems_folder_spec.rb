require "spec_helper"

describe EmsFolder do
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
