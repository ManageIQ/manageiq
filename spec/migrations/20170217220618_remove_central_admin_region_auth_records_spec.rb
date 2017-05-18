require_migration

describe RemoveCentralAdminRegionAuthRecords do
  let(:authentication_stub) { migration_stub(:Authentication) }

  migration_context :up do
    it "removes rows that point to MiqRegion" do
      authentication_stub.create!(:resource_type => "MiqRegion")
      authentication_stub.create!(:resource_type => "MiqRegion")
      authentication_stub.create!(:resource_type => "Provider")

      migrate

      expect(authentication_stub.count).to eq(1)
      expect(authentication_stub.first.resource_type).to eq("Provider")
    end
  end
end
