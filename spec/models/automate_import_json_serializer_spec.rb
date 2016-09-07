describe AutomateImportJsonSerializer do
  let(:automate_import_json_serializer) { described_class.new }

  describe '#serialize' do
    let(:miq_ae_yaml_import_zipfs) { double('MiqAeYamlImportZipfs') }
    let(:import_file_upload) { double('ImportFileUpload') }
    let(:binary_blob) { double('BinaryBlob') }

    let(:expected_json) do
      [
        {
          'text'       => 'Customer',
          'key'        => 'Customer',
          'image'      => ActionController::Base.helpers.image_path('100/ae_domain.png'),
          'selectable' => false,
          'nodes'      => [
            {
              'text'       => 'EVMApplications',
              'key'        => 'EVMApplications',
              'image'      => ActionController::Base.helpers.image_path('100/ae_namespace.png'),
              'selectable' => false,
              'nodes'      => [
                {
                  'text'       => 'Operations',
                  'key'        => 'EVMApplications/Operations',
                  'image'      => ActionController::Base.helpers.image_path('100/ae_namespace.png'),
                  'selectable' => false,
                  'nodes'      => [
                    {
                      'text'       => 'Profile',
                      'key'        => 'EVMApplications/Operations/Profile',
                      'image'      => ActionController::Base.helpers.image_path('100/ae_namespace.png'),
                      'selectable' => false,
                      'nodes'      => []
                    }, {
                      'text'       => 'Profile.class',
                      'key'        => 'EVMApplications/Operations/Profile.class',
                      'image'      => ActionController::Base.helpers.image_path('100/ae_class.png'),
                      'selectable' => false
                    }
                  ]
                }
              ]
            }
          ]
        }, {
          'text'       => 'ManageIQ',
          'key'        => 'ManageIQ',
          'image'      => ActionController::Base.helpers.image_path('100/ae_domain.png'),
          'selectable' => false,
          'nodes'      => [],
        }
      ]
    end

    before do
      allow(import_file_upload).to receive(:binary_blob).and_return(binary_blob)
      allow(binary_blob).to receive(:binary).and_return('a bunch of junk')
      allow(MiqAeImport).to receive(:new).with('*', 'zip_file' => 'automate_temporary_zip.zip').and_return(miq_ae_yaml_import_zipfs)
      allow(miq_ae_yaml_import_zipfs).to receive(:domain_entries).with('*').and_return(['Customer/test1.yml', 'ManageIQ/test2.yml'])
      allow(miq_ae_yaml_import_zipfs).to receive(:namespace_files).with('Customer').and_return(
        ['Customer/EVMApplications/test.yml']
      )
      allow(miq_ae_yaml_import_zipfs).to receive(:namespace_files).with('ManageIQ').and_return([])
      allow(miq_ae_yaml_import_zipfs).to receive(:namespace_files).with('Customer/EVMApplications').and_return(
        ['Customer/EVMApplications/Operations/test.yml']
      )
      allow(miq_ae_yaml_import_zipfs).to receive(:namespace_files).with('Customer/EVMApplications/Operations').and_return(
        ['Customer/EVMApplications/Operations/Profile/test.yml']
      )
      allow(miq_ae_yaml_import_zipfs).to receive(:namespace_files).with('Customer/EVMApplications/Operations/Profile').and_return([])

      allow(miq_ae_yaml_import_zipfs).to receive(:class_files).with('Customer').and_return([])
      allow(miq_ae_yaml_import_zipfs).to receive(:class_files).with('Customer/EVMApplications').and_return([])
      allow(miq_ae_yaml_import_zipfs).to receive(:class_files).with('Customer/EVMApplications/Operations').and_return(
        ['Customer/EVMApplications/Operations/Profile.class/test.yml']
      )
      allow(miq_ae_yaml_import_zipfs).to receive(:class_files).with('Customer/EVMApplications/Operations/Profile').and_return([])
      allow(miq_ae_yaml_import_zipfs).to receive(:class_files).with('ManageIQ').and_return([])
    end

    it 'returns the correct json' do
      expect(JSON.parse(automate_import_json_serializer.serialize(import_file_upload))).to eq(expected_json)
    end
  end
end
