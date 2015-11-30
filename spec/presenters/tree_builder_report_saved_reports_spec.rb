require "spec_helper"
require "helpers/report_helper_spec"

describe TreeBuilderReportSavedReports do
  include CompressedIds

  describe "#x_get_tree_roots" do
    context "User1 has Group1(current group: Group1), User2 has Group1, Group2(current group: Group2)" do
      before :each do
        EvmSpecHelper.local_miq_server

        MiqUserRole.seed
        role = MiqUserRole.find_by_name("EvmRole-operator")

        # User1 with 2 groups(Group1,Group2), current group for User2 is Group2
        create_user_with_group('User2', "Group1", role)

        @user1 = create_user_with_group('User1', "Group2", role)
        @user1.miq_groups << MiqGroup.where(:description => "Group1")
        login_as @user1
      end

      context "User2 generates report under Group1" do
        before :each do
          @rpt = create_and_generate_report_for_user("Vendor and Guest OS", "User2")
        end

        it "is allowed to see report created under Group1 for User 1(with current group Group2)" do
          # there is calling of x_get_tree_roots
          tree = TreeBuilderReportSavedReports.new('savedreports_tree', 'savedreports', {})

          saved_reports_in_tree = JSON.parse(tree.tree_nodes).first['children']

          displayed_report_ids = saved_reports_in_tree.map do |saved_report|
            from_cid(saved_report["key"].gsub("xx-", ""))
          end

          # logged User1 can see report with Group1
          expect(displayed_report_ids).to include(@rpt.id)
        end
      end
    end
  end
end
