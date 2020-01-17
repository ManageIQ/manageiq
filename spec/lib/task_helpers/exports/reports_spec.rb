RSpec.describe TaskHelpers::Exports::Reports do
  let(:export_dir) do
    Dir.mktmpdir('miq_exp_dir')
  end

  before do
    FactoryBot.create(:miq_report,
                      :name       => "Test Report",
                      :rpt_type   => "Custom",
                      :tz         => "Eastern Time (US & Canada)",
                      :col_order  => %w(name boot_time disks_aligned),
                      :cols       => %w(name boot_time disks_aligned),
                      :db_options => { :rpt_type => "ChargebackContainerProject" },
                      "include"   => { "columns" => %w(col1 col2) })
    FactoryBot.create(:miq_report,
                      :name       => "Test Report 2",
                      :rpt_type   => "Custom",
                      :tz         => "Eastern Time (US & Canada)",
                      :col_order  => %w(name boot_time disks_aligned),
                      :cols       => %w(name boot_time disks_aligned),
                      :db_options => { :rpt_type => "ChargebackContainerProject" },
                      "include"   => { "columns" => %w(col1 col2) })
    FactoryBot.create(:miq_report,
                      :name       => "Default Test Report",
                      :rpt_type   => "Default",
                      :tz         => "Eastern Time (US & Canada)",
                      :col_order  => %w(name boot_time disks_aligned),
                      :cols       => %w(name boot_time disks_aligned),
                      :db_options => { :rpt_type => "ChargebackContainerProject" },
                      "include"   => { "columns" => %w(col1 col2) })
  end

  after do
    FileUtils.remove_entry export_dir
  end

  describe "when --all is not specified" do
    let(:report_filename1) { "#{export_dir}/Test_Report.yaml" }
    let(:report_filename2) { "#{export_dir}/Test_Report_2.yaml" }

    it "exports custom reports to individual files in a given directory" do
      TaskHelpers::Exports::Reports.new.export(:directory => export_dir)
      expect(Dir[File.join(export_dir, '**', '*')].count { |file| File.file?(file) }).to eq(2)
      report1 = YAML.load_file(report_filename1)
      expect(report1.first["MiqReport"]["menu_name"]).to eq("Test Report")
      report2 = YAML.load_file(report_filename2)
      expect(report2.first["MiqReport"]["menu_name"]).to eq("Test Report 2")
    end
  end

  describe "when --all is specified" do
    let(:report_filename1) { "#{export_dir}/Test_Report.yaml" }
    let(:report_filename2) { "#{export_dir}/Test_Report_2.yaml" }
    let(:report_filename3) { "#{export_dir}/Default_Test_Report.yaml" }

    it "exports all reports to individual files in a given directory" do
      TaskHelpers::Exports::Reports.new.export(:directory => export_dir, :all => true)
      expect(Dir[File.join(export_dir, '**', '*')].count { |file| File.file?(file) }).to eq(3)
      report1 = YAML.load_file(report_filename1)
      expect(report1.first["MiqReport"]["menu_name"]).to eq("Test Report")
      report2 = YAML.load_file(report_filename2)
      expect(report2.first["MiqReport"]["menu_name"]).to eq("Test Report 2")
      report3 = YAML.load_file(report_filename3)
      expect(report3.first["MiqReport"]["menu_name"]).to eq("Default Test Report")
    end
  end
end
