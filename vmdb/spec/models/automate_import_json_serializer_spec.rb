require "spec_helper"
require "miq_ae_yaml_import_zipfs"

describe AutomateImportJsonSerializer do
  let(:automate_import_json_serializer) { described_class.new }

  describe "#serialize" do
    let(:miq_ae_yaml_import_zipfs) { instance_double("MiqAeYamlImportZipfs") }
    let(:import_file_upload) { active_record_instance_double("ImportFileUpload") }
    let(:binary_blob) { active_record_instance_double("BinaryBlob") }

    let(:expected_json) do
      {
        :children => [{
          :title    => "Customer",
          :key      => "Customer",
          :icon     => "/images/icons/new/ae_domain.png",
          :children => [{
            :title    => "EVMApplications",
            :key      => "EVMApplications",
            :icon     => "/images/icons/new/ae_namespace.png",
            :children => [{
              :title    => "Operations",
              :key      => "EVMApplications/Operations",
              :icon     => "/images/icons/new/ae_namespace.png",
              :children => [{
                :title    => "Profile",
                :key      => "EVMApplications/Operations/Profile",
                :icon     => "/images/icons/new/ae_namespace.png",
                :children => [],
              }],
            }],
          }]
        }, {
          :title    => "ManageIQ",
          :key      => "ManageIQ",
          :icon     => "/images/icons/new/ae_domain.png",
          :children => []
        }]
      }.to_json
    end

    before do
      import_file_upload.stub(:binary_blob).and_return(binary_blob)
      binary_blob.stub(:binary).and_return("a bunch of junk")
      MiqAeImport.stub(:new).with("*", "zip_file" => "automate_temporary_zip.zip").and_return(miq_ae_yaml_import_zipfs)
      miq_ae_yaml_import_zipfs.stub(:domain_entries).with("*").and_return(["Customer/test1.yml", "ManageIQ/test2.yml"])
      miq_ae_yaml_import_zipfs.stub(:namespace_files).with("Customer").and_return([
        "Customer/EVMApplications/test.yml"
      ])
      miq_ae_yaml_import_zipfs.stub(:namespace_files).with("ManageIQ").and_return([])
      miq_ae_yaml_import_zipfs.stub(:namespace_files).with("Customer/EVMApplications").and_return([
        "Customer/EVMApplications/Operations/test.yml"
      ])
      miq_ae_yaml_import_zipfs.stub(:namespace_files).with("Customer/EVMApplications/Operations").and_return([
        "Customer/EVMApplications/Operations/Profile/test.yml"
      ])
      miq_ae_yaml_import_zipfs.stub(:namespace_files).with("Customer/EVMApplications/Operations/Profile").and_return([])
    end

    it "returns the correct json" do
      expect(automate_import_json_serializer.serialize(import_file_upload)).to eq(expected_json)
    end
  end
end
