require_migration

describe UpdateOVirtApiPath do
  let(:ems_stub) { migration_stub(:ExtManagementSystem) }
  let(:endpoint_stub) { migration_stub(:Endpoint) }

  migration_context :up do
    it 'updates the path for the default endpoint of oVirt providers' do
      ems_stub.create!(
        :type => 'ManageIQ::Providers::Redhat::InfraManager',
        :id   => 1
      )
      endpoint_stub.create!(
        :id            => 1,
        :resource_type => 'ExtManagementSystem',
        :resource_id   => 1,
        :role          => 'default',
        :path          => '/api'
      )

      migrate

      expect(endpoint_stub.where(:id => 1).first.path).to eq('/ovirt-engine/api')
    end

    it 'does not update the path if it has been already customized' do
      ems_stub.create!(
        :type => 'ManageIQ::Providers::Redhat::InfraManager',
        :id   => 1
      )
      endpoint_stub.create!(
        :id            => 1,
        :resource_type => 'ExtManagementSystem',
        :resource_id   => 1,
        :role          => 'default',
        :path          => '/myapi'
      )

      migrate

      expect(endpoint_stub.where(:id => 1).first.path).to eq('/myapi')
    end

    it 'does not update the path for the metrics endpoint of oVirt providers' do
      ems_stub.create!(
        :type => 'ManageIQ::Providers::Redhat::InfraManager',
        :id   => 1
      )
      endpoint_stub.create!(
        :id            => 1,
        :resource_type => 'ExtManagementSystem',
        :resource_id   => 1,
        :role          => 'metrics',
        :path          => '/api'
      )

      migrate

      expect(endpoint_stub.where(:id => 1).first.path).to eq('/api')
    end

    it 'does not update the path for other type of provider' do
      ems_stub.create!(
        :type => 'ManageIQ::Providers::Amazon::InfraManager',
        :id   => 1
      )
      endpoint_stub.create!(
        :id            => 1,
        :resource_type => 'ExtManagementSystem',
        :resource_id   => 1,
        :role          => 'default',
        :path          => '/api'
      )

      migrate

      expect(endpoint_stub.where(:id => 1).first.path).to eq('/api')
    end

    it 'does not update the path for other type of resource, even if they have the same resource id' do
      ems_stub.create!(
        :type => 'ManageIQ::Providers::Redhat::InfraManager',
        :id   => 1
      )
      endpoint_stub.create!(
        :id            => 1,
        :resource_type => 'ExtManagementSystem',
        :resource_id   => 1,
        :role          => 'default',
        :path          => '/api'
      )
      endpoint_stub.create!(
        :id            => 2,
        :resource_type => 'DoNotTouch',
        :resource_id   => 1,
        :role          => 'default',
        :path          => '/api'
      )

      migrate

      expect(endpoint_stub.where(:id => 1).first.path).to eq('/ovirt-engine/api')
      expect(endpoint_stub.where(:id => 2).first.path).to eq('/api')
    end
  end
end
