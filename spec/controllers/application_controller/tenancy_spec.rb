require "spec_helper"

describe DashboardController do
  before do
    EvmSpecHelper.create_guid_miq_server_zone
    Tenant.seed
    ActsAsTenant.default_tenant = Tenant.default_tenant
  end

  context "#with unknown subdomain or domain" do
    before do
      @request.host = "www.example.com"
    end

    it "defaults to default_domain" do
      get :login
      expect(controller.send(:current_tenant)).to eq(Tenant.default_tenant)
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
