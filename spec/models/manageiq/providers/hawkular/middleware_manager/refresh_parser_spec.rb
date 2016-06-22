require 'spec_helper'
require 'recursive-open-struct'

describe ManageIQ::Providers::Hawkular::MiddlewareManager::RefreshParser do
  let(:ems_hawkular) do
    # allow(MiqServer).to receive(:my_zone).and_return("default")
    _guid, _server, zone = EvmSpecHelper.create_guid_miq_server_zone
    auth = AuthToken.new(:name => "test", :auth_key => "valid-token", :userid => "jdoe", :password => "password")
    FactoryGirl.create(:ems_hawkular,
                       :hostname        => 'localhost',
                       :port            => 8080,
                       :authentications => [auth],
                       :zone            => zone)
  end
  let(:parser) { described_class.new(ems_hawkular) }
  let(:server) do
    FactoryGirl.create(:hawkular_middleware_server,
                       :name                  => 'Local',
                       :feed                  => 'cda13e2a-e206-4e87-8bca-8cfdd5aea484',
                       :ems_ref               => '/t;28026b36-8fe4-4332-84c8-524e173a68bf'\
                                                 '/f;cda13e2a-e206-4e87-8bca-8cfdd5aea484/r;Local~~',
                       :nativeid              => 'Local~~',
                       :ext_management_system => ems_hawkular)
  end

  describe 'parse_datasource' do
    it 'handles simple data' do
      # parse_datasource(server, datasource, config)
      datasource = RecursiveOpenStruct.new(:name => 'ruby-sample-build',
                                           :id   => 'Local~/subsystem=datasources/data-source=ExampleDS',
                                           :path => '/t;28026b36-8fe4-4332-84c8-524e173a68bf'\
                                                    '/f;cda13e2a-e206-4e87-8bca-8cfdd5aea484/r;Local~~'\
                                                    '/r;Local~%2Fsubsystem%3Ddatasources%2Fdata-source%3DExampleDS'
                                          )
      config = {
        'value' => {
          'Driver Name'    => 'h2',
          'JNDI Name'      => 'java:jboss/datasources/ExampleDS',
          'Connection URL' => 'jdbc:h2:mem:test;DB_CLOSE_DELAY=-1;DB_CLOSE_ON_EXIT=FALSE',
          'Enabled'        => 'true'
        }
      }
      parsed_datasource = {
        :name              => 'ruby-sample-build',
        :middleware_server => server,
        :nativeid          => 'Local~/subsystem=datasources/data-source=ExampleDS',
        :ems_ref           => '/t;28026b36-8fe4-4332-84c8-524e173a68bf'\
                                                 '/f;cda13e2a-e206-4e87-8bca-8cfdd5aea484/r;Local~~'\
                                                 '/r;Local~%2Fsubsystem%3Ddatasources%2Fdata-source%3DExampleDS',
        :properties        => {
          'Driver Name'    => 'h2',
          'JNDI Name'      => 'java:jboss/datasources/ExampleDS',
          'Connection URL' => 'jdbc:h2:mem:test;DB_CLOSE_DELAY=-1;DB_CLOSE_ON_EXIT=FALSE',
          'Enabled'        => 'true'
        }
      }
      expect(parser.send(:parse_datasource, server, datasource, config)).to eq(parsed_datasource)
    end
  end

  describe 'alternate_machine_id' do
    it 'should transform machine ID to dmidecode BIOS UUID' do
      # the /etc/machine-id is usually in downcase, and the dmidecode BIOS UUID is usually upcase
      # the alternate_machine_id should *just* swap digits, it should not handle upcase/downcase.
      # 33D1682F-BCA4-4B4C-B19E-CB47D344746C is a real BIOS UUID retrieved from a VM
      # 33d1682f-bca4-4b4c-b19e-cb47d344746c is what other providers store in the DB
      # 2f68d133a4bc4c4bb19ecb47d344746c is the machine ID for the BIOS UUID above
      # at the Middleware Provider, we get the second version, while the first is usually used by other providers
      machine_id = '2f68d133a4bc4c4bb19ecb47d344746c'
      expected = '33d1682f-bca4-4b4c-b19e-cb47d344746c'
      expect(parser.alternate_machine_id(machine_id)).to eq(expected)

      # and now we reverse the operation, just as a sanity check
      machine_id = '33d1682fbca44b4cb19ecb47d344746c'
      expected = '2f68d133-a4bc-4c4b-b19e-cb47d344746c'
      expect(parser.alternate_machine_id(machine_id)).to eq(expected)
    end
  end

  describe 'swap_part' do
    it 'should swap and reverse every two bytes of a machine ID part' do
      # the /etc/machine-id is usually in downcase, and the dmidecode BIOS UUID is usually upcase
      # the alternate_machine_id should *just* swap digits, it should not handle upcase/downcase.
      # 33D1682F-BCA4-4B4C-B19E-CB47D344746C is a real BIOS UUID retrieved from a VM
      # 33d1682f-bca4-4b4c-b19e-cb47d344746c is what other providers store in the DB
      # 2f68d133a4bc4c4bb19ecb47d344746c is the machine ID for the BIOS UUID above
      # at the Middleware Provider, we get the second version, while the first is usually used by other providers
      part = '2f68d133'
      expected = '33d1682f'
      expect(parser.swap_part(part)).to eq(expected)

      # and now we reverse the operation, just as a sanity check
      part = '33d1682f'
      expected = '2f68d133'
      expect(parser.swap_part(part)).to eq(expected)
    end
  end
end
