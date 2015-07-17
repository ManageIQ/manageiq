require "spec_helper"

describe MiqReportResult do
  before(:each) do
    MiqRegion.seed
    guid = MiqUUID.new_guid
    MiqServer.stub(:my_guid => guid)
    FactoryGirl.create(:miq_server, :zone => FactoryGirl.create(:zone), :guid => guid, :status => "started")
    MiqServer.my_server(true)

    @group = FactoryGirl.create(:miq_group)
    @user  = FactoryGirl.create(:user, :miq_groups => [@group])

    5.times do |i|
      vm = FactoryGirl.build(:vm_vmware)
      vm.evm_owner_id = @user.id           if i > 2
      vm.miq_group_id = @user.current_group.id if vm.evm_owner_id || (i > 1)
      vm.save
    end

    @report_theme = 'miq'
    @show_title   = true
    @options = MiqReport.graph_options(600, 400)

    Charting.stub(:detect_available_plugin).and_return(JqplotCharting)
  end

  context "persisting generated report results" do
    it "should save the original report metadata and the generated table as a binary blob" do
      MiqReport.seed_report(name = "Vendor and Guest OS")
      rpt = MiqReport.where(:name => name).last
      rpt.generate_table(:userid => "test")
      report_result = rpt.build_create_results(:userid => "test")

      report_result.reload

      report_result.should_not be_nil
      report_result.report.kind_of?(MiqReport).should be_true
      report_result.binary_blob.should_not be_nil
      report_result.report_results.kind_of?(MiqReport).should be_true
      report_result.report_results.table.should_not be_nil
      report_result.report_results.table.data.should_not be_nil
    end
  end
end