require "spec_helper"
require Rails.root.join("db/migrate/20150619153304_miq_report_result_fix_serialized_report.rb")

describe MiqReportResultFixSerializedReport do
  let(:report_result_stub)  { migration_stub(:MiqReportResult) }
  let(:data_dir) { File.join(Rails.root, 'spec/migrations/data', File.basename(__FILE__, '.rb')) }

  migration_context :up do
    before(:each) do
      @raw_report = File.read(File.join(data_dir, 'miq_report_obj.yaml'))
    end

    it "migrates existing reports serialized as MiqReport objects to Hashes" do
      rr = report_result_stub.create!(
          :db     => 'Chargeback',
          :report => @raw_report
      )

      migrate

      rr.reload

      raw_report = YAML.load(rr.read_attribute(:report))
      expect(raw_report).to be_a(Hash)
    end
  end

  migration_context :down do
    before(:each) do
      @raw_report = File.read(File.join(data_dir, 'miq_report_hash.yaml'))
    end

    it "migrates existing reports serialized as Hashes objects to MiqReports" do
      rr = report_result_stub.create!(
          :db     => 'Chargeback',
          :report => @raw_report
      )

      migrate

      rr.reload

      raw_report = YAML.load(rr.read_attribute(:report))
      expect(raw_report).to be_a(Array)
      expect(raw_report.first).to be_a(MiqReport)
    end
  end
end