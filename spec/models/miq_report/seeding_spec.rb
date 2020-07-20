require 'fileutils'

RSpec.describe MiqReport do
  describe "::Seeding" do
    include_examples ".seed called multiple times"

    describe ".seed" do
      let(:tmpdir)      { Pathname.new(Dir.mktmpdir) }
      let(:reports_dir) { tmpdir.join("product/reports") }
      let(:compare_dir) { tmpdir.join("product/compare") }
      let(:report_yml)  { reports_dir.join("1_Testing Group/022_Testing Report.yaml") }
      let(:compare_yml) { compare_dir.join("testing.yaml") }
      let(:data_dir)    { Pathname.new(__dir__).join("data/product") }

      before do
        FileUtils.mkdir_p(reports_dir)
        FileUtils.cp_r(Rails.root.join("product/reports/520_Events - Policy"), reports_dir, preserve: true)
        FileUtils.cp_r(Rails.root.join("product/compare"), tmpdir.join("product"), preserve: true)

        stub_const("MiqReport::Seeding::REPORT_DIR", reports_dir)
        stub_const("MiqReport::Seeding::COMPARE_DIR", compare_dir)
      end

      after do
        FileUtils.rm_rf(tmpdir)
      end

      # This test is intentionally long winded instead of breaking it up into
      # multiple tests per concern because of how long a full seed takes.
      # Breaking it into individual tests would increase runtime a lot.
      it "creates, updates, and changes records" do
        described_class.seed

        expect(MiqReport.where(:name => "Policy Events for Last Week")).to exist
        expect(MiqReport.where(:name => "VMs: Compare Template")).to exist

        expect(MiqReport.where(:name => "Testing Report Name")).to_not exist
        expect(MiqReport.where(:name => "Testing Compare Name")).to_not exist

        # Add new records
        FileUtils.cp_r(data_dir, tmpdir, preserve: true)

        described_class.seed

        report  = MiqReport.find_by(:name => "Testing Report Name")
        compare = MiqReport.find_by(:name => "Testing Compare Name")

        expect(report).to have_attributes(
          :name          => "Testing Report Name",
          :title         => "Testing Report Title",
          :rpt_group     => "Testing Group",
          :rpt_type      => "Default",
          :template_type => "report",
          :priority      => 22,
          :filename      => "1_Testing Group/022_Testing Report.yaml",
          :file_mtime    => File.mtime(report_yml).utc.round,
          :db            => "Vm",
          :cols          => ["vendor_display", "name"],
          :include       => {"operating_system" => {"columns" => ["product_name", "name"]}},
        )

        expect(compare).to have_attributes(
          :name          => "Testing Compare Name",
          :title         => "Testing Compare Template",
          :rpt_group     => "compare",
          :rpt_type      => "Default",
          :template_type => "compare",
          :priority      => 0,
          :filename      => "testing.yaml",
          :file_mtime    => File.mtime(compare_yml).utc.round,
          :db            => "VmOrTemplate",
          :cols          => ["name", "vendor"]
        )

        # Update reports
        report_mtime  = report.file_mtime
        compare_mtime = compare.file_mtime

        # The mtime rounding is granular to the second, so need to be higher
        # than that for test purposes
        FileUtils.touch(report_yml,  mtime: 1.second.from_now.to_time)
        FileUtils.touch(compare_yml, mtime: 1.second.from_now.to_time)

        described_class.seed

        expect(report.reload.file_mtime).to_not  eq(report_mtime)
        expect(compare.reload.file_mtime).to_not eq(compare_mtime)

        # Delete reports
        FileUtils.rm_f(report_yml)
        FileUtils.rm_f(compare_yml)

        described_class.seed

        expect { report.reload }.to  raise_error(ActiveRecord::RecordNotFound)
        expect { compare.reload }.to raise_error(ActiveRecord::RecordNotFound)

        # Duplicate custom reports by name will be skipped in seeding
        custom_report  = FactoryBot.create(:miq_report, :name => "Testing Report Name",  :rpt_type => "Custom", :template_type => "report")
        custom_compare = FactoryBot.create(:miq_report, :name => "Testing Compare Name", :rpt_type => "Custom", :template_type => "compare")

        described_class.seed

        expect(described_class.where(:name => custom_report.name).count).to eq(1)
        expect(custom_report.reload.rpt_type).to eq("Custom")
        expect(described_class.where(:name => custom_compare.name).count).to eq(1)
        expect(custom_compare.reload.rpt_type).to eq("Custom")
      end

      it "updates attributes of existing record if yaml renamed" do
        old_yaml_file = "520_Events - Policy/110_Policy Events.yaml"
        new_yaml_file = "520_Events - Policy/some_new_name.yaml"
        described_class.seed
        report = MiqReport.find_by(:name => "Policy Events for Last Week")
        expect(report.filename).to eq(old_yaml_file)

        FileUtils.mv(reports_dir.join(old_yaml_file), reports_dir.join(new_yaml_file))
        described_class.seed

        report = MiqReport.find_by(:name => "Policy Events for Last Week")
        expect(report.filename).to eq(new_yaml_file)
      end
    end
  end
end
