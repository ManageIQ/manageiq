describe ServiceTemplateCatalog do
  let(:root_tenant) do
    Tenant.seed
  end

  describe "#name" do
    it "is unique per tenant" do
      FactoryGirl.create(:service_template_catalog, :name => "common", :tenant => root_tenant)
      expect { FactoryGirl.create(:service_template_catalog, :name => "common", :tenant => root_tenant) }
        .to raise_error(ActiveRecord::RecordInvalid, /Name has already been taken/)
    end

    it "can be the same across tenants" do
      tenant1 = FactoryGirl.create(:tenant, :parent => root_tenant)
      tenant2 = FactoryGirl.create(:tenant, :parent => root_tenant)
      FactoryGirl.create(:service_template_catalog, :name => "common", :tenant => tenant1)
      expect do
        FactoryGirl.build(:service_template_catalog, :name => "common", :tenant => tenant2)
      end.not_to raise_error
    end
  end
end
