require "spec_helper"

describe ServiceTemplateCatalog do
  let(:root_tenant) do
    EvmSpecHelper.create_root_tenant
  end

  describe "#name" do
    it "is unique per tenant" do
      FactoryGirl.create(:service_template_catalog, :name => "common", :tenant => root_tenant)
      expect do
        FactoryGirl.create(:service_template_catalog, :name => "common", :tenant => root_tenant)
      end.to raise_error
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
