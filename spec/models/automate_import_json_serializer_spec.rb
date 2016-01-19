describe AutomateImportJsonSerializer do
  let(:automate_import_json_serializer) { described_class.new }

  describe "#serialize" do
    let(:miq_ae_yaml_import_zipfs) { double("MiqAeYamlImportZipfs") }
    let(:import_file_upload) { double("ImportFileUpload") }
    let(:binary_blob) { double("BinaryBlob") }

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
              }, {
                :title => "Profile.class",
                :key   => "EVMApplications/Operations/Profile.class",
                :icon  => "/images/icons/new/ae_class.png"
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
      allow(import_file_upload).to receive(:binary_blob).and_return(binary_blob)
      allow(binary_blob).to receive(:binary).and_return("a bunch of junk")
      allow(MiqAeImport).to receive(:new).with("*", "zip_file" => "automate_temporary_zip.zip").and_return(miq_ae_yaml_import_zipfs)
      allow(miq_ae_yaml_import_zipfs).to receive(:domain_entries).with("*").and_return(["Customer/test1.yml", "ManageIQ/test2.yml"])
      allow(miq_ae_yaml_import_zipfs).to receive(:namespace_files).with("Customer").and_return([
        "Customer/EVMApplications/test.yml"
      ])
      allow(miq_ae_yaml_import_zipfs).to receive(:namespace_files).with("ManageIQ").and_return([])
      allow(miq_ae_yaml_import_zipfs).to receive(:namespace_files).with("Customer/EVMApplications").and_return([
        "Customer/EVMApplications/Operations/test.yml"
      ])
      allow(miq_ae_yaml_import_zipfs).to receive(:namespace_files).with("Customer/EVMApplications/Operations").and_return([
        "Customer/EVMApplications/Operations/Profile/test.yml"
      ])
      allow(miq_ae_yaml_import_zipfs).to receive(:namespace_files).with("Customer/EVMApplications/Operations/Profile").and_return([])

      allow(miq_ae_yaml_import_zipfs).to receive(:class_files).with("Customer").and_return([])
      allow(miq_ae_yaml_import_zipfs).to receive(:class_files).with("Customer/EVMApplications").and_return([])
      allow(miq_ae_yaml_import_zipfs).to receive(:class_files).with("Customer/EVMApplications/Operations").and_return([
        "Customer/EVMApplications/Operations/Profile.class/test.yml"
      ])
      allow(miq_ae_yaml_import_zipfs).to receive(:class_files).with("Customer/EVMApplications/Operations/Profile").and_return([])
      allow(miq_ae_yaml_import_zipfs).to receive(:class_files).with("ManageIQ").and_return([])
    end

    it "returns the correct json" do
      expect(automate_import_json_serializer.serialize(import_file_upload)).to eq(expected_json)
    end
  end
end
