require_migration

describe FixNullVerifySslOnEndpoints do
  let(:endpoint_stub) { migration_stub(:Endpoint) }

  migration_context :up do
    it "changes verify_ssl to 1 only for the nil ones" do
      endpoint_stub.create!(:verify_ssl => nil)
      endpoint_stub.create!(:verify_ssl => 0)
      endpoint_stub.create!(:verify_ssl => 1)

      migrate

      expect(endpoint_stub.where(:verify_ssl => nil).count).to eq 0
      expect(endpoint_stub.where(:verify_ssl => 0).count).to eq 1
      expect(endpoint_stub.where(:verify_ssl => 1).count).to eq 2
    end
  end
end
