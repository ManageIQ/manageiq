$LOAD_PATH << Rails.root.join("tools").to_s

require 'copy_reports_structure/report_structure'

describe ReportStructure do
  let(:group_name) { "SourceGroup" }
  let(:settings) { {"reports_menus" => [["Configuration Management", ["Virtual Machines", ["Vendor and Type"]]]]} }
  let(:role)  { FactoryGirl.create(:miq_user_role) }
  let(:source_group) {  FactoryGirl.create(:miq_group, :settings => settings) }
  let(:destination_group) { FactoryGirl.create(:miq_group, :miq_user_role => role) }

  context "copy reports structure" do
    describe ".duplicate_for_group" do
      it "copies reports structure from one group to another" do
        ReportStructure.duplicate_for_group(source_group.description, destination_group.description)
        destination_group.reload
        expect(destination_group.settings).to eq(settings)
      end

      it "does not copy reports structure if dry_run is set to true" do
        ReportStructure.duplicate_for_group(source_group.description, destination_group.description, true)
        destination_group.reload
        expect(destination_group.settings).to be nil
      end

      it "does not change reports structure on destination group is source group not found" do
        expect(ReportStructure).to receive(:abort)
        ReportStructure.duplicate_for_group("Some_Not_existed_Group", source_group.description)
        source_group.reload
        expect(source_group.settings).to eq(settings)
      end
    end

    describe ".duplicate_for_role" do
      before do
        @destination_group2 = FactoryGirl.create(:miq_group, :miq_user_role => destination_group.miq_user_role)
      end

      it "copies reports structure from one group to role (to all groups having that role)" do
        ReportStructure.duplicate_for_role(source_group.description, role.name)
        destination_group.reload
        expect(destination_group.settings).to eq(settings)
        @destination_group2.reload
        expect(@destination_group2.settings).to eq(settings)
      end

      it "does not copy reports structure if dry_run is set to true" do
        ReportStructure.duplicate_for_role(source_group.description, role.name, true)
        destination_group.reload
        expect(destination_group.settings).to be nil
        @destination_group2.reload
        expect(@destination_group2.settings).to be nil
      end

      it "does not change reports structure on group with destination role is source group not found" do
        destination_group.update(:settings => settings)
        expect(ReportStructure).to receive(:abort)
        ReportStructure.duplicate_for_role("Some_Not_existed_Group", role.name)
        destination_group.reload
        expect(destination_group.settings).to eq(settings)
      end
    end
  end
end