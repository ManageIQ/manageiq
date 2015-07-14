require "spec_helper"
require Rails.root.join("db/migrate/20150625220141_fix_serialized_reports_for_rails_four.rb")

describe FixSerializedReportsForRailsFour do
  let(:report_result_stub)  { migration_stub(:MiqReportResult) }
  let(:binary_blob)  { migration_stub(:BinaryBlob) }
  let(:data_dir) { File.join(Rails.root, 'spec/migrations/data', File.basename(__FILE__, '.rb')) }

  migration_context :up do
    before(:each) do
      @raw_report   = File.read(File.join(data_dir, 'miq_report_obj.yaml'))
      @raw_blob     = File.read(File.join(data_dir, 'binary_blob_obj.yaml'))
      @raw_blob_csv = File.read(File.join(data_dir, 'binary_blob_csv.yaml'))
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

    it "migrates existing binary blobs serialized as MiqReport objects to Hashes" do
      bb = binary_blob.create!(
        :resource_type => "MiqReportResult",
        :md5           => "b540c6aec8a7726c1154d71c06017150",
        :size          => 67_124,
        :part_size     => 1_048_576,
        :name          => "report_results",
        :data_type     => "YAML"
      )
      bb.binary = @raw_blob

      migrate

      bb.reload

      raw_report = YAML.load(bb.binary)
      expect(raw_report).to be_a(Hash)
    end

    it "skips existing binary blobs serialized as CSV" do
      bb = binary_blob.create!(
          :resource_type => "MiqReportResult",
          :md5           => "b540c6aec8a7726c1154d71c06017150",
          :size          => 67_124,
          :part_size     => 1_048_576,
          :name          => "report_results",
          :data_type     => "YAML"
      )
      bb.binary = @raw_blob_csv.dup

      migrate

      bb.reload

      expect(bb.binary).to eq(@raw_blob_csv)
    end
  end

  migration_context :down do
    before(:each) do
      @raw_report   = File.read(File.join(data_dir, 'miq_report_hash.yaml'))
      @raw_blob     = File.read(File.join(data_dir, 'binary_blob_hash.yaml'))
      @raw_blob_csv = File.read(File.join(data_dir, 'binary_blob_csv.yaml'))
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

    it "migrates existing binary blobs serialized as Hashes objects to MiqReports" do
      bb = binary_blob.create!(
        :resource_type => "MiqReportResult",
        :md5           => "b540c6aec8a7726c1154d71c06017150",
        :size          => 67_124,
        :part_size     => 1_048_576,
        :name          => "report_results",
        :data_type     => "YAML"
      )
      bb.binary = @raw_blob

      migrate

      bb.reload

      raw_report = YAML.load(bb.binary)
      expect(raw_report).to be_a(MiqReport)
    end


    it "skips existing binary blobs serialized as CSV" do
      bb = binary_blob.create!(
          :resource_type => "MiqReportResult",
          :md5           => "b540c6aec8a7726c1154d71c06017150",
          :size          => 67_124,
          :part_size     => 1_048_576,
          :name          => "report_results",
          :data_type     => "YAML"
      )
      bb.binary = @raw_blob_csv.dup

      migrate

      bb.reload

      expect(bb.binary).to eq(@raw_blob_csv)
    end
  end
end
