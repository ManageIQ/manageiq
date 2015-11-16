require "spec_helper"

describe MiqReportResult do
  context "persisting generated report results" do
    before(:each) do
      EvmSpecHelper.local_miq_server

      user = FactoryGirl.create(:user_with_group)

      5.times do |i|
        vm = FactoryGirl.build(:vm_vmware)
        vm.evm_owner_id = user.id               if i > 2
        vm.miq_group_id = user.current_group.id if vm.evm_owner_id || (i > 1)
        vm.save
      end

      @report_theme = 'miq'
      @show_title   = true
      @options = MiqReport.graph_options(600, 400)

      Charting.stub(:detect_available_plugin).and_return(JqplotCharting)
    end

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

  describe "serializing and deserializing report results" do
    it "can serialize and deserialize an MiqReport" do
      report = FactoryGirl.build(:miq_report)
      report_result = described_class.new

      report_result.report_results = report

      expect(report_result.report_results.to_hash).to eq(report.to_hash)
    end

    it "can serialize and deserialize a CSV" do
      csv = CSV.generate { |c| c << %w(foo bar) << %w(baz qux) }
      report_result = described_class.new

      report_result.report_results = csv

      expect(report_result.report_results).to eq(csv)
    end

    it "can serialize and deserialize a plain text report" do
      txt = <<EOF
+--------------+
|  Foo Report  |
+--------------+
| Foo  | Bar   |
+--------------+
| baz  | qux   |
| quux | corge |
+--------------+
EOF
      report_result = described_class.new

      report_result.report_results = txt

      expect(report_result.report_results).to eq(txt)
    end
  end
end
