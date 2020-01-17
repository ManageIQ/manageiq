RSpec.describe FirmwareRegistry::RestApiDepot do
  before do
    VCR.configure do |config|
      config.filter_sensitive_data('AUTHORIZATION') { Base64.encode64("#{user}:#{pass}").chomp }
      config.before_record { |interaction| interaction.request.uri.downcase! }
    end
    # Is seems some other test is turning VCR off in some random cases.
    # We're best off manually turning it on.
    VCR.turn_on!
  end

  let(:host) { Rails.application.secrets.fwreg_rest_api_depot.try(:[], 'host') || 'host' }
  let(:user) { Rails.application.secrets.fwreg_rest_api_depot.try(:[], 'userid') || 'username' }
  let(:pass) { Rails.application.secrets.fwreg_rest_api_depot.try(:[], 'password') || 'password' }
  let(:url) { "http://#{host}/images/" }

  describe '.fetch_from_remote' do
    context 'when 200' do
      it 'list of firmware binaries is returned' do
        with_vcr('when-200') do
          expect(described_class.fetch_from_remote(url, user, pass)).to be_an Array
        end
      end
    end

    context 'when bad credentials' do
      it 'managed error is raised' do
        with_vcr('when-bad-credentials') do
          expect { described_class.fetch_from_remote(url, 'bad-username', 'bad-password') }.to raise_error(MiqException::Error)
        end
      end
    end

    context 'when bad host' do
      it 'managed error is raised' do
        with_vcr('when-bad-host') do
          expect { described_class.fetch_from_remote('http://bad.host', 'user', 'pass') }.to raise_error(MiqException::Error)
        end
      end
    end

    context 'when bad json' do
      it 'managed error is raised' do
        with_vcr('when-bad-json') do
          expect { described_class.fetch_from_remote(url, user, pass) }.to raise_error(MiqException::Error)
        end
      end
    end
  end

  describe '#sync_fw_binaries_raw' do
    before     { allow(described_class).to receive(:fetch_from_remote).and_return(json) }
    let(:json) { [] }
    subject    { FactoryBot.create(:firmware_registry_rest_api_depot) }

    context 'when on empty database' do
      before { assert_counts(:firmware_registry => 0, :firmware_binary => 0, :firmware_target => 0) }

      context 'using simple inline fixture' do
        let(:json) do
          [
            {
              'description'              => 'Some Binary Description',
              'urls'                     => [
                'http://url.net =>1000',
                'https://url.net =>1443',
              ],
              'compatible_server_models' => [
                {
                  'model'        => 'Common Model',
                  'manufacturer' => 'Common Manufacturer'
                }
              ],
              'version'                  => 'v1.2.3',
              'filename'                 => 'some.binary.name'
            }
          ]
        end

        it 'binary is inventoried' do
          subject.sync_fw_binaries_raw
          subject.reload
          assert_counts(:firmware_binary => 1)
          expect(FirmwareBinary.first).to have_attributes(
            :name              => 'some.binary.name',
            :description       => 'Some Binary Description',
            :version           => 'v1.2.3',
            :firmware_registry => subject,
            :firmware_targets  => [FirmwareTarget.first]
          )
        end

        it 'target is inventoried' do
          subject.sync_fw_binaries_raw
          subject.reload
          assert_counts(:firmware_target => 1)
          expect(FirmwareTarget.first).to have_attributes(
            :manufacturer      => 'common manufacturer',
            :model             => 'common model',
            :firmware_binaries => [FirmwareBinary.first]
          )
        end

        it 'refresh twice' do
          2.times { subject.sync_fw_binaries_raw }
          assert_counts(:firmware_registry => 1, :firmware_binary => 1, :firmware_target => 1)
        end
      end

      context 'using json fixture' do
        let(:json) { JSON.parse(File.read(File.join(File.dirname(__FILE__), 'data', 'sample_firmware_binaries.json'))) }

        it 'inventories specific entities' do
          subject.sync_fw_binaries_raw
          subject.reload
          assert_counts(:firmware_registry => 1, :firmware_binary => json.size, :firmware_target => 3)
          expect(FirmwareBinary.find_by(:name => 'dell-bios-2019-03-23.bin')).to have_attributes(
            :description       => 'DELL BIOS update',
            :version           => '10.4.3',
            :firmware_registry => subject,
            :firmware_targets  => [FirmwareTarget.find_by(:model => 'common model')]
          )
        end
      end
    end

    context 'when on existing database' do
      let!(:binary) { FactoryBot.create(:firmware_binary, :firmware_registry => subject) }
      let!(:target) { FactoryBot.create(:firmware_target, :firmware_binaries => [binary]) }
      let(:json) do
        [
          {
            'description'              => 'Updated Description',
            'urls'                     => [
              'http://url.net =>1000',
              'https://url.net =>1443',
            ],
            'compatible_server_models' => [
              {
                'model'        => 'Updated Model',
                'manufacturer' => 'Updated Manufacturer'
              }
            ],
            'version'                  => 'v1.2.3',
            'filename'                 => binary.name
          }
        ]
      end

      it 'binary is updated' do
        subject.sync_fw_binaries_raw
        subject.reload
        assert_counts(:firmware_binary => 1)
        expect(FirmwareBinary.first).to have_attributes(
          :name              => binary.name,
          :description       => 'Updated Description',
          :version           => 'v1.2.3',
          :firmware_registry => subject,
          :firmware_targets  => [FirmwareTarget.find_by(:model => 'updated model')]
        )
      end
    end

    def assert_counts(counts)
      expect(FirmwareRegistry.count).to eq(counts[:firmware_registry]) if counts.include?(:firmware_registry)
      expect(FirmwareBinary.count).to eq(counts[:firmware_binary]) if counts.include?(:firmware_binary)
      expect(FirmwareTarget.count).to eq(counts[:firmware_target]) if counts.include?(:firmware_target)
    end
  end

  describe '.do_create_firmware_registry' do
    let(:options) do
      {
        :name     => 'name',
        :url      => 'http://my-registry.com:1234/images',
        :userid   => 'username',
        :password => 'password'
      }
    end

    context 'when options are valid' do
      it 'creates new firmware registry' do
        registry = described_class.do_create_firmware_registry(options)
        expect(registry.name).to eq('name')
        expect(registry.authentication).to have_attributes(:userid => 'username', :password => 'password')
        expect(registry.endpoint).to have_attributes(:url => 'http://my-registry.com:1234/images')
      end
    end
  end

  describe '.validate_options' do
    let(:options) do
      {
        :name     => 'name',
        :url      => 'http://my-registry.com:1234/images',
        :userid   => 'username',
        :password => 'password'
      }
    end

    it 'when options are valid' do
      expect { described_class.validate_options(options) }.not_to raise_error
    end

    context 'when options are invalid' do
      %i[name userid password url].each do |key|
        context "(#{key} is missing)" do
          before { options.delete(key) }
          it 'error is raised' do
            expect { described_class.validate_options(options) }.to raise_error(MiqException::Error)
          end
        end
      end
    end
  end

  def with_vcr(suffix)
    path = "#{described_class.name.underscore}_#{suffix}"
    VCR.use_cassette(path, :match_requests_on => [:method, :path]) { yield }
  end
end
