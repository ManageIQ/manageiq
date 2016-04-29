require_migration

describe MoveFiltersToEntitlements do
  let(:miq_group_stub)   { migration_stub(:MiqGroup) }
  let(:entitlement_stub) { migration_stub(:Entitlement) }
  let(:filters) do
    {"managed"   => [["/hue/hue/hue", "/stuff"], ["here"]],
     "belongsto" => ["/stuffs/here"]}
  end

  migration_context :up do
    let!(:miq_group) do
      miq_group_stub.create!(:entitlement => entitlement,
                             :filters     => filters)
    end
    let!(:entitlement) { entitlement_stub.create!(:filters => nil) }

    it "moves filters to the associated entitlement" do
      expect(entitlement.filters).to be_nil
      migrate
      expect(entitlement.reload.filters).to eq(filters)
    end
  end

  migration_context :down do
    let!(:miq_group) do
      miq_group_stub.create!(:entitlement => entitlement,
                             :filters     => nil)
    end
    let!(:entitlement) { entitlement_stub.create!(:filters => filters) }

    it "moves filters to the associated entitlement" do
      expect(miq_group.filters).to be_nil
      migrate
      expect(miq_group.reload.filters).to eq(filters)
    end
  end
end
