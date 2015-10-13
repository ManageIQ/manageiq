require "spec_helper"

RSpec.describe "tenants API" do
  include Rack::Test::Methods

  def app
    Vmdb::Application
  end

  before { init_api_spec_env }
  let!(:root_tenant) { Tenant.seed }

  it "can list all the tenants" do
    api_basic_authorize action_identifier(:tenants, :read, :collection_actions, :get)
    tenant_1 = FactoryGirl.create(:tenant, :parent => root_tenant)
    tenant_2 = FactoryGirl.create(:tenant, :parent => root_tenant)

    run_get tenants_url

    expect_result_resources_to_include_hrefs(
      "resources",
      [
        tenants_url(root_tenant.id),
        tenants_url(tenant_1.id),
        tenants_url(tenant_2.id)
      ]
    )

    expect_request_success
  end

  it "can show a single tenant" do
    api_basic_authorize action_identifier(:tenants, :read, :resource_actions, :get)
    tenant = FactoryGirl.create(
      :tenant,
      :parent      => root_tenant,
      :name        => "Test Tenant",
      :description => "Tenant for this test"
    )

    run_get tenants_url(tenant.id)

    expect_result_to_match_hash(
      @result,
      "href"        => tenants_url(tenant.id),
      "id"          => tenant.id,
      "name"        => "Test Tenant",
      "description" => "Tenant for this test"
    )
    expect_request_success
  end

  context "with an appropriate role" do
    it "can create a tenant" do
      api_basic_authorize collection_action_identifier(:tenants, :create)

      expect do
        run_post tenants_url, :parent => {:id => root_tenant.id}
      end.to change(Tenant, :count).by(1)

      expect_request_success
    end

    it "will not create a tenant with an invalid parent" do
      api_basic_authorize collection_action_identifier(:tenants, :create)
      invalid_tenant = FactoryGirl.create(:tenant, :parent => root_tenant).destroy

      expect do
        run_post tenants_url, :parent => {:id => invalid_tenant.id}
      end.not_to change(Tenant, :count)

      expect_bad_request
      expect(@result["error"]["message"]).to match(/Failed to add a new tenant resource/)
    end

    it "can update a tenant with POST" do
      api_basic_authorize action_identifier(:tenants, :edit)
      tenant = FactoryGirl.create(
        :tenant,
        :parent      => root_tenant,
        :name        => "Test Tenant",
        :description => "Tenant for this test"
      )
      options = {:name => "New Tenant name", :description => "New Tenant description"}

      run_post tenants_url(tenant.id), gen_request(:edit, options)

      expect_request_success
      tenant.reload
      expect(tenant.name).to eq("New Tenant name")
      expect(tenant.description).to eq("New Tenant description")
    end

    it "can update a tenant with PUT" do
      api_basic_authorize action_identifier(:tenants, :edit)
      tenant = FactoryGirl.create(
        :tenant,
        :parent      => root_tenant,
        :name        => "Test Tenant",
        :description => "Tenant for this test"
      )
      options = {:name => "New Tenant name", :description => "New Tenant description"}

      run_put tenants_url(tenant.id), options

      expect_request_success
      tenant.reload
      expect(tenant.name).to eq("New Tenant name")
      expect(tenant.description).to eq("New Tenant description")
    end

    it "can update multiple tenants with POST" do
      api_basic_authorize action_identifier(:tenants, :edit)
      tenant_1 = FactoryGirl.create(
        :tenant,
        :parent => root_tenant,
        :name   => "Test Tenant 1"
      )
      tenant_2 = FactoryGirl.create(
        :tenant,
        :parent => root_tenant,
        :name   => "Test Tenant 2"
      )
      options = [
        {"href" => tenants_url(tenant_1.id), "name" => "Updated Test Tenant 1"},
        {"href" => tenants_url(tenant_2.id), "name" => "Updated Test Tenant 2"}
      ]

      run_post tenants_url, gen_request(:edit, options)

      expect_request_success
      expect_results_to_match_hash(
        "results",
        [{"id" => tenant_1.id, "name" => "Updated Test Tenant 1"},
         {"id" => tenant_2.id, "name" => "Updated Test Tenant 2"}]
      )
      expect(tenant_1.reload.name).to eq("Updated Test Tenant 1")
      expect(tenant_2.reload.name).to eq("Updated Test Tenant 2")
    end

    it "can delete a tenant with POST" do
      api_basic_authorize action_identifier(:tenants, :delete)
      tenant = FactoryGirl.create(:tenant, :parent => root_tenant)

      expect { run_post tenants_url(tenant.id), gen_request(:delete) }.to change(Tenant, :count).by(-1)
      expect_request_success
    end

    it "can delete a tenant with DELETE" do
      api_basic_authorize action_identifier(:tenants, :delete)
      tenant = FactoryGirl.create(:tenant, :parent => root_tenant)

      expect { run_delete tenants_url(tenant.id) }.to change(Tenant, :count).by(-1)
      expect_request_success_with_no_content
    end

    it "can delete multiple tenants with POST" do
      api_basic_authorize action_identifier(:tenants, :delete)
      tenant_1 = FactoryGirl.create(:tenant, :parent => root_tenant)
      tenant_2 = FactoryGirl.create(:tenant, :parent => root_tenant)
      options = [
        {"href" => tenants_url(tenant_1.id)},
        {"href" => tenants_url(tenant_2.id)}
      ]

      expect do
        run_post tenants_url, gen_request(:delete, options)
      end.to change(Tenant, :count).by(-2)
      expect_request_success
    end
  end

  context "without an appropriate role" do
    it "will not create a tenant" do
      api_basic_authorize

      expect do
        run_post tenants_url, :parent => {:id => root_tenant.id}
      end.not_to change(Tenant, :count)

      expect_request_forbidden
    end

    it "will not update a tenant with POST" do
      api_basic_authorize
      tenant = FactoryGirl.create(
        :tenant,
        :parent      => root_tenant,
        :name        => "Test Tenant",
        :description => "Tenant for this test"
      )
      options = {:name => "New Tenant name", :description => "New Tenant description"}

      run_post tenants_url(tenant.id), gen_request(:edit, options)

      expect_request_forbidden
      tenant.reload
      expect(tenant.name).to eq("Test Tenant")
      expect(tenant.description).to eq("Tenant for this test")
    end

    it "will not update a tenant with PUT" do
      api_basic_authorize
      tenant = FactoryGirl.create(
        :tenant,
        :parent      => root_tenant,
        :name        => "Test Tenant",
        :description => "Tenant for this test"
      )
      options = {:name => "New Tenant name", :description => "New Tenant description"}

      run_put tenants_url(tenant.id), options

      expect_request_forbidden
      tenant.reload
      expect(tenant.name).to eq("Test Tenant")
      expect(tenant.description).to eq("Tenant for this test")
    end

    it "will not update multiple tenants with POST" do
      api_basic_authorize
      tenant_1 = FactoryGirl.create(
        :tenant,
        :parent => root_tenant,
        :name   => "Test Tenant 1"
      )
      tenant_2 = FactoryGirl.create(
        :tenant,
        :parent => root_tenant,
        :name   => "Test Tenant 2"
      )
      options = [
        {"href" => tenants_url(tenant_1.id), "name" => "Updated Test Tenant 1"},
        {"href" => tenants_url(tenant_2.id), "name" => "Updated Test Tenant 2"}
      ]

      run_post tenants_url, gen_request(:edit, options)

      expect_request_forbidden
      expect(tenant_1.reload.name).to eq("Test Tenant 1")
      expect(tenant_2.reload.name).to eq("Test Tenant 2")
    end

    it "will not delete a tenant with POST" do
      api_basic_authorize
      tenant = FactoryGirl.create(:tenant, :parent => root_tenant)

      expect { run_post tenants_url(tenant.id), gen_request(:delete) }.not_to change(Tenant, :count)
      expect_request_forbidden
    end

    it "will not delete a tenant with DELETE" do
      api_basic_authorize
      tenant = FactoryGirl.create(:tenant, :parent => root_tenant)

      expect { run_delete tenants_url(tenant.id) }.not_to change(Tenant, :count)
      expect_request_forbidden
    end

    it "will not update multiple tenants with POST" do
      api_basic_authorize
      tenant_1 = FactoryGirl.create(:tenant, :parent => root_tenant)
      tenant_2 = FactoryGirl.create(:tenant, :parent => root_tenant)
      options = [
        {"href" => tenants_url(tenant_1.id)},
        {"href" => tenants_url(tenant_2.id)}
      ]

      expect do
        run_post tenants_url, gen_request(:delete, options)
      end.not_to change(Tenant, :count)
      expect_request_forbidden
    end
  end
end
