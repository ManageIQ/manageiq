require_migration

describe MigrateUrlFromProviderToEndpoints do
  let(:provider_stub) { migration_stub(:Provider) }
  let(:endpoint_stub) { migration_stub(:Endpoint) }
  let(:ems_stub)      { migration_stub(:ExtManagementSystem) }

  migration_context :up do
    it 'migrates Provider URL to Endpoints' do
      provider = provider_stub.create!(
        :url => "example.com"
      )
      ems_stub.create!(
        :provider_id => provider.id
      )

      migrate

      expect(endpoint_stub.count).to eq(1)
      expect(endpoint_stub.first).to have_attributes(
        :url => "example.com"
      )
    end

    it 'handles nil port value properly' do
      provider = provider_stub.create!(
        :url => nil
      )
      ems_stub.create!(
        :provider_id => provider.id
      )

      migrate

      expect(endpoint_stub.first).to have_attributes(
        :url => nil
      )
    end
  end

  migration_context :down do
    it 'migrates Endpoint URL to Provider attributes' do
      provider = provider_stub.create!
      ems      = ems_stub.create!(
        :provider_id => provider.id
      )
      endpoint_stub.create!(
        :resource_type => "Provider",
        :resource_id   => ems.id,
        :role          => "default",
        :url           => "example.com"
      )

      migrate

      expect(endpoint_stub.count).to eq(0)
      expect(provider.reload).to have_attributes(
        :url => "example.com"
      )
    end

    it 'handles nil port value properly' do
      provider = provider_stub.create!
      endpoint_stub.create!(
        :url => nil
      )

      migrate

      expect(provider.reload).to have_attributes(
        :url => nil
      )
    end
  end
end
