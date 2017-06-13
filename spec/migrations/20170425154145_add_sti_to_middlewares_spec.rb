require_migration

describe AddStiToMiddlewares do
  constants = %w(
    MiddlewareDatasource
    MiddlewareDeployment
    MiddlewareDomain
    MiddlewareMessaging
    MiddlewareServer
    MiddlewareServerGroup
  )

  migration_context :up do
    constants.each do |klass|
      it "migrates all #{klass}" do
        result = migration_stub(klass.to_sym).create!

        migrate

        result.reload
        expect(result).to have_attributes(:type => "ManageIQ::Providers::Hawkular::MiddlewareManager::#{klass}")
      end
    end
  end
end
