require_migration

describe MigrateEmsAttributesToEndpoints do
  let(:ems_stub)      { migration_stub(:ExtManagementSystem) }
  let(:endpoint_stub) { migration_stub(:Endpoint) }

  migration_context :up do
    it 'migrates EMS attributes to endpoints' do
      ems = ems_stub.create!(
        :ipaddress => "1.2.3.4",
        :hostname  => "example.org",
        :port      => "123"
      )

      migrate

      expect(endpoint_stub.count).to eq(1)
      expect(endpoint_stub.first).to have_attributes(
        :role          => "default",
        :ipaddress     => "1.2.3.4",
        :hostname      => "example.org",
        :port          => 123,
        :resource_type => "ExtManagementSystem",
        :resource_id   => ems.id
      )
    end

    it 'handles nil port value properly' do
      ems_stub.create!(
        :ipaddress => "1.2.3.4",
        :hostname  => "example.org",
      )

      migrate

      expect(endpoint_stub.first).to have_attributes(
        :ipaddress => "1.2.3.4",
        :hostname  => "example.org",
        :port      => nil,
      )
    end
  end

  migration_context :down do
    it 'migrates endpoints to EMS attributes' do
      ems = ems_stub.create!
      endpoint_stub.create!(
        :role          => "default",
        :ipaddress     => "1.2.3.4",
        :hostname      => "example.org",
        :port          => 123,
        :resource_type => "ExtManagementSystem",
        :resource_id   => ems.id
      )

      migrate

      expect(endpoint_stub.count).to eq(0)
      expect(ems.reload).to have_attributes(
        :ipaddress => "1.2.3.4",
        :hostname  => "example.org",
        :port      => "123",
      )
    end

    it 'handles nil port value properly' do
      ems = ems_stub.create!
      endpoint_stub.create!(
        :role          => "default",
        :ipaddress     => "1.2.3.4",
        :hostname      => "example.org",
        :resource_type => "ExtManagementSystem",
        :resource_id   => ems.id
      )

      migrate

      expect(ems.reload).to have_attributes(
        :ipaddress => "1.2.3.4",
        :hostname  => "example.org",
        :port      => nil,
      )
    end
  end
end
