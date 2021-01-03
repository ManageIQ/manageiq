RSpec.describe ServiceTemplateCatalog do
  let(:root_tenant) do
    Tenant.seed
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
