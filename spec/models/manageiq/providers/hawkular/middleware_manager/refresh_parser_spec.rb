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
end
