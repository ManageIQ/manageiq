require_migration

describe MoveFiltersToEntitlements do
  let(:miq_group_stub)   { migration_stub(:MiqGroup) }
  let(:entitlement_stub) { migration_stub(:Entitlement) }

  let(:filters1) do
    {"managed"   => ["/managed/operations/analysis_failed"],
     "belongsto" => ["/belongsto/ExtManagementSystem|RHEVM"]}
  end

  let(:filters2) do
    {"managed"   => [],
     "invalid"   => [":trollface:"],
     "belongsto" => ["/belongsto/ExtManagementSystem|RHEVM"]}
  end

  let(:filters3) { nil }

  migration_context :up do
    1.upto(3) do |n|
      let!("miq_group#{n}") do
        miq_group_stub.create!(:filters => send("filters#{n}"))
      end
    end

    before do
      migrate
      1.upto(3) { |n| send("miq_group#{n}").reload }
    end

    it "sets the filters on the entitlement appropriately and clears the group filters" do
      expect(miq_group1.filters).to be_nil
      expect(miq_group2.filters).to be_nil
      expect(miq_group3.filters).to be_nil

      expect(miq_group1.entitlement.tag_filters).to eq(filters1["managed"])
      expect(miq_group1.entitlement.resource_filters).to eq(filters1["belongsto"])

      expect(miq_group2.entitlement.tag_filters).to eq(filters2["managed"])
      expect(miq_group2.entitlement.resource_filters).to eq(filters2["belongsto"])

      expect(miq_group3.entitlement).to be_nil
    end
  end

  migration_context :down do
    1.upto(2) do |n|
      let!("miq_group#{n}") do
        miq_group_stub.create!(:entitlement => entitlement_stub.create!(:tag_filters      => send("filters#{n}")["managed"],
                                                                        :resource_filters => send("filters#{n}")["belongsto"]))
      end
    end
    let!(:miq_group3) { miq_group_stub.create!(:entitlement => nil) }

    before do
      migrate
      1.upto(3) { |n| send("miq_group#{n}").reload }
    end

    it "sets the filters back on miq_group and clears the entitlement filters" do
      expect(miq_group1.entitlement.tag_filters).to be_empty
      expect(miq_group1.entitlement.resource_filters).to be_empty
      expect(miq_group2.entitlement.tag_filters).to be_empty
      expect(miq_group2.entitlement.resource_filters).to be_empty
      expect(miq_group3.entitlement).not_to be_present

      expect(miq_group1.filters).to eq(filters1)
      expect(miq_group2.filters).to eq(filters2.slice("belongsto", "managed"))
      expect(miq_group3.filters).to eq(filters3)
    end
  end
end
