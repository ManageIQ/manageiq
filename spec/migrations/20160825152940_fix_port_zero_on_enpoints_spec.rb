require_migration

describe FixPortZeroOnEnpoints do
  let(:endpoint_stub) { migration_stub(:Endpoint) }

  migration_context :up do
    it "changes ports only for those with 0" do
      endpoint_stub.create!(:port => nil)
      endpoint_stub.create!(:port => 0)
      endpoint_stub.create!(:port => 443)

      migrate

      expect(endpoint_stub.where(:port => nil).count).to eq 2
      expect(endpoint_stub.where(:port => 0).count).to eq 0
      expect(endpoint_stub.where(:port => 443).count).to eq 1
    end
  end
end
