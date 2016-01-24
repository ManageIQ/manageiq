require "helpers/report_helper_spec"

describe TreeBuilderReportSavedReports do
  include CompressedIds

  context "User1 has Group1(current group: Group1), User2 has Group1, Group2(current group: Group2)" do
    context "User2 generates report under Group1" do
      before do
        EvmSpecHelper.local_miq_server

        MiqUserRole.seed
        role = MiqUserRole.find_by_name("EvmRole-operator")

        # User1 with current group Group2
        @user1 = create_user_with_group('User1', "Group1", role)

        # User2 with 2 groups(Group1,Group2), current group: Group2
        @user2 = create_user_with_group('User2', "Group2", role)
        @user2.miq_groups << MiqGroup.where(:description => "Group1")

        login_as @user2
        @rpt = create_and_generate_report_for_user("Vendor and Guest OS", "User1")
      end

      describe "#x_get_tree_roots" do
        it "is allowed to see report created under Group1 for User2(with current group Group2)" do
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

      describe "#x_get_tree_custom_kids" do
        it "is allowed to see report results created under Group1 for User2(with current group Group2)" do
          report_result = MiqReportResult.first

          tree = TreeBuilderReportSavedReports.new('savedreports_tree', 'savedreports', {})
          tree_report_results = tree.send(:x_get_tree_custom_kids, {:id => to_cid(@rpt.id)}, false, {})

          expect(tree_report_results).to include(report_result)
        end
      end
    end
  end
end
