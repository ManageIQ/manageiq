require_migration

describe MigrateSecurityProtocolAtributeToEndpoints do
  let(:endpoint_stub) { migration_stub(:Endpoint) }
  let(:ems_stub)      { migration_stub(:ExtManagementSystem) }

  migration_context :up do
    it 'migrates Security Protocol to Endpoints' do
      ems_stub.create!(
        :security_protocol => "ssl"
      )

      migrate

      expect(endpoint_stub.count).to eq(1)
      expect(endpoint_stub.first).to have_attributes(
        :security_protocol => "ssl"
      )
    end
  end

  migration_context :down do
    it 'migrates Endpoint security_protocol to EMS' do
      ems = ems_stub.create!

      endpoint_stub.create!(
        :resource_type => "ExtManagementSystem",
        :resource_id   => ems.id,
        :role          => "default",
        :security_protocol => "ssl"
      )

      migrate

      expect(endpoint_stub.count).to eq(0)
      expect(ems.reload).to have_attributes(
        :security_protocol => "ssl"
      )
    end
  end
end
