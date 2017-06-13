require_migration

describe RemoveInvalidHawkularEndpoints do
  let(:ext_management_system_stub) { migration_stub(:ExtManagementSystem) }
  let(:endpoint_stub) { migration_stub(:Endpoint) }
  let(:authentication_stub) { migration_stub(:Authentication) }

  migration_context :up do
    it 'Remove hawkular endpoints that are nil' do
      ems = ext_management_system_stub.create!(
        :name => 'container',
        :type => 'ManageIQ::Providers::Openshift::ContainerManager'
      )
      endpoint_stub.create!(
        :role          => "default",
        :hostname      => "hostname",
        :port          => 123,
        :resource_type => "ExtManagementSystem",
        :resource_id   => ems.id
      )
      endpoint_stub.create!(
        :role          => "hawkular",
        :hostname      => nil,
        :port          => 123,
        :resource_type => "ExtManagementSystem",
        :resource_id   => ems.id
      )
      authentication_stub.create!(
        :name          => "#{ems.type} #{ems.name}",
        :authtype      => "bearer",
        :resource_type => "ExtManagementSystem",
        :resource_id   => ems.id,
        :type          => "AuthToken"
      )
      authentication_stub.create!(
        :name          => "#{ems.type} #{ems.name}",
        :authtype      => "hawkular",
        :resource_type => "ExtManagementSystem",
        :resource_id   => ems.id,
        :type          => "AuthToken"
      )
      migrate
      expect(endpoint_stub.pluck(:role)).to contain_exactly("default")
      expect(authentication_stub.pluck(:authtype)).to contain_exactly("bearer")
    end

    it 'Does not remove hawkular endpoints that are not nil' do
      ems = ext_management_system_stub.create!
      endpoint_stub.create!(
        :role          => "default",
        :hostname      => "hostname",
        :port          => 123,
        :resource_type => "ExtManagementSystem",
        :resource_id   => ems.id
      )
      endpoint_stub.create!(
        :role          => "hawkular",
        :hostname      => "somevalue",
        :port          => 123,
        :resource_type => "ExtManagementSystem",
        :resource_id   => ems.id
      )
      authentication_stub.create!(
        :name          => "#{ems.type} #{ems.name}",
        :authtype      => "bearer",
        :resource_type => "ExtManagementSystem",
        :resource_id   => ems.id,
        :type          => "AuthToken"
      )
      authentication_stub.create!(
        :name          => "#{ems.type} #{ems.name}",
        :authtype      => "hawkular",
        :resource_type => "ExtManagementSystem",
        :resource_id   => ems.id,
        :type          => "AuthToken"
      )
      migrate
      ems.reload
      expect(endpoint_stub.count).to eq(2)
      expect(authentication_stub.count).to eq(2)
    end
  end
end
