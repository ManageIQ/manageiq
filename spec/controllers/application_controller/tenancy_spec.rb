require "spec_helper"

describe DashboardController do
  before do
    EvmSpecHelper.create_guid_miq_server_zone
  end

  describe "#current_tenant" do
    it "defaults to the default tenant" do
      get :login
      expect(controller.send(:current_tenant)).to be_default
    end

    it "uses the user's tenant" do
      tenant = FactoryGirl.create(:tenant, :parent => Tenant.root_tenant)
      user = FactoryGirl.create(:user, :miq_groups => [FactoryGirl.create(:miq_group, :tenant => tenant)])
      login_as user
      get :login
      expect(controller.send(:current_tenant)).to eq(tenant)
    end

    # context "#with unknown subdomain or domain" do
    #   before do
    #     EvmSpecHelper.create_root_tenant
    #     @request.host = "www.example.com"
    #   end

    #   # assumes database is empty and has no tenant objects
    #   it "defaults to default_domain" do
    #     get :login
    #     expect(controller.send(:current_tenant)).to be_default
    #   end
    # end

    # context "#with known subdomain" do
    #   let(:tenant) { Tenant.create(:subdomain => "subdomain", :parent => Tenant.default_tenant) }
    #   before do
    #     @request.host = "#{tenant.subdomain}.example.com"
    #   end

    #   it "detects tenant by subdomain" do
    #     get :login
    #     expect(controller.send(:current_tenant)).to eq(tenant)
    #   end
    # end

    # context "#with known domain" do
    #   let(:tenant) { Tenant.create(:domain => "domain.com", :parent => Tenant.default_tenant) }
    #   before do
    #     @request.host = "www.#{tenant.domain}"
    #   end

    #   it "detects tenant by subdomain" do
    #     get :login
    #     expect(controller.send(:current_tenant)).to eq(tenant)
    #   end
    # end
  end
end
