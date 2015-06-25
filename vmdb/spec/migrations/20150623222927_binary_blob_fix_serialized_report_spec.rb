require "spec_helper"
require Rails.root.join("db/migrate/20150623222927_binary_blob_fix_serialized_report.rb")

describe BinaryBlobFixSerializedReport do
  let(:binary_blob)  { migration_stub(:BinaryBlob) }
  let(:data_dir) { File.join(Rails.root, 'spec/migrations/data', File.basename(__FILE__, '.rb')) }

  migration_context :up do
    before(:each) do
      @raw_report = File.read(File.join(data_dir, 'miq_report_obj.yaml'))
      # BinaryBlob.any_instance.stub(:binary).and_return(@raw_report)
    end

    it "migrates existing reports serialized as MiqReport objects to Hashes" do
      bb = binary_blob.create!(
          :resource_type => "MiqReportResult",
          # :resource_id => 7,
          :md5 => "b540c6aec8a7726c1154d71c06017150",
          :size => 67124,
          :part_size => 1048576,
          :name => "report_results",
          :data_type => "YAML"
      )
      bb.binary = @raw_report

      migrate

      bb.reload

      raw_report = YAML.load(bb.binary)
      expect(raw_report).to be_a(Hash)
    end
  end

  migration_context :down do
    before(:each) do
      @raw_report = File.read(File.join(data_dir, 'miq_report_hash.yaml'))
    end

    it "migrates existing reports serialized as Hashes objects to MiqReports" do
      bb = binary_blob.create!(
          :resource_type => "MiqReportResult",
          # :resource_id => 7,
          :md5 => "b540c6aec8a7726c1154d71c06017150",
          :size => 67124,
          :part_size => 1048576,
          :name => "report_results",
          :data_type => "YAML"
      )
      bb.binary = @raw_report

      migrate

      bb.reload

      raw_report = YAML.load(bb.binary)
      expect(raw_report).to be_a(MiqReport)
    end
  end
end