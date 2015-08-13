require "spec_helper"

describe DashboardController do
  before do
    EvmSpecHelper.create_guid_miq_server_zone
  end

  context "#with unknown subdomain or domain" do
    before do
      # acts_as_tenant initializer
      Tenant.seed
      ActsAsTenant.default_tenant = Tenant.default_tenant
      # end of acts_as_tenant_initializer
      @request.host = "www.example.com"
    end

    # assumes database is empty and has no tenant objects
    it "defaults to default_domain" do
      get :login
      expect(controller.send(:current_tenant)).to be_default
    end
  end

  context "#with known subdomain" do
    let(:tenant) { Tenant.create(:subdomain => "subdomain") }
    before do
      @request.host = "#{tenant.subdomain}.example.com"
    end

    it "detects tenant by subdomain" do
      get :login
      expect(controller.send(:current_tenant)).to eq(tenant)
    end
  end

  context "#with known domain" do
    let(:tenant) { Tenant.create(:domain => "domain.com") }
    before do
      @request.host = "www.#{tenant.domain}"
    end

    it "detects tenant by subdomain" do
      get :login
      expect(controller.send(:current_tenant)).to eq(tenant)
    end
  end
end
