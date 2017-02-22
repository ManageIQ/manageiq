require_migration

describe AddInitiatorToService do
  let(:service_stub) { migration_stub(:Service) }
  let(:default_initiator) { "user" }

  migration_context :up do
    it "adds initiator and sets it to user" do
      service_stub.create!(:name => 'service1')
      service_stub.create!(:name => 'service2')

      migrate

      expect(service_stub.count).to eq(2)
      expect(service_stub.find_by(:name => 'service1').initiator).to eq(default_initiator)
      expect(service_stub.find_by(:name => 'service1').initiator).to eq(default_initiator)
    end
  end

  migration_context :down do
    it "removes initiator" do
      service_stub.create!(:name => 'service1', :initiator => default_initiator)
      service_stub.create!(:name => 'service2', :initiator => default_initiator)

      migrate

      expect(service_stub.count).to eq(2)
      expect(service_stub.columns.collect(&:name).exclude?('initiator')).to be_truthy
    end
  end

end
