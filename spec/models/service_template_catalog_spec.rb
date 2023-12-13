RSpec.describe ServiceTemplateCatalog do
  let(:root_tenant) do
    Tenant.seed
  end

  describe ".seed" do
    it "seeds when the table is empty" do
      expect(described_class.count).to eq(0)

      described_class.seed

      expect(described_class.count).to eq(1)
      expect(described_class.first.name).to eq("My Catalog")
    end

    it "does not seed when the table is not empty" do
      described_class.create!(:name => "Custom Catalog", :tenant => root_tenant)

      described_class.seed

      expect(described_class.count).to eq(1)
      expect(described_class.first.name).to eq("Custom Catalog")
    end
  end

  it "doesn’t access database when unchanged model is saved" do
    f1 = described_class.create!(:name => 'f1')
    expect { f1.valid? }.to make_database_queries(:count => 2)
  end

  describe "#name" do
    it "is unique per tenant" do
      FactoryBot.create(:service_template_catalog, :name => "common", :tenant => root_tenant)
      expect { FactoryBot.create(:service_template_catalog, :name => "common", :tenant => root_tenant) }
        .to raise_error(ActiveRecord::RecordInvalid, /Name has already been taken/)
    end

    it "can be the same across tenants" do
      tenant1 = FactoryBot.create(:tenant, :parent => root_tenant)
      tenant2 = FactoryBot.create(:tenant, :parent => root_tenant)
      FactoryBot.create(:service_template_catalog, :name => "common", :tenant => tenant1)
      expect do
        FactoryBot.build(:service_template_catalog, :name => "common", :tenant => tenant2)
      end.not_to raise_error
    end
  end
end
