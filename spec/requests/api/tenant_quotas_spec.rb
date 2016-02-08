describe "tenant quotas API" do
  let!(:root_tenant) { Tenant.seed }

  it "can list all the quotas form a tenant" do
    api_basic_authorize action_identifier(:quotas, :read, :subcollection_actions, :get)

    tenant = FactoryGirl.create(:tenant, :parent => root_tenant)
    quota_1 = FactoryGirl.create(:tenant_quota, :tenant_id => tenant.id, :name => :cpu_allocated, :value => 1)
    quota_2 = FactoryGirl.create(:tenant_quota, :tenant_id => tenant.id, :name => :mem_allocated, :value => 20)

    run_get "/api/tenants/#{tenant.id}/quotas"

    expect_result_resources_to_include_hrefs(
      "resources",
      [
        "/api/tenants/#{tenant.id}/quotas/#{quota_1.id}",
        "/api/tenants/#{tenant.id}/quotas/#{quota_2.id}",
      ]
    )

    expect_request_success
  end

  it "can show a single quota from a tenant" do
    api_basic_authorize action_identifier(:quotas, :read, :subresource_actions, :get)

    tenant = FactoryGirl.create(:tenant, :parent => root_tenant)
    quota = FactoryGirl.create(:tenant_quota, :tenant_id => tenant.id, :name => :cpu_allocated, :value => 1)

    run_get "/api/tenants/#{tenant.id}/quotas/#{quota.id}"

    expect_result_to_match_hash(
      response_hash,
      "href"      => "/api/tenants/#{tenant.id}/quotas/#{quota.id}",
      "id"        => quota.id,
      "tenant_id" => tenant.id,
      "name"      => "cpu_allocated",
      "unit"      => "fixnum",
      "value"     => 1.0
    )
    expect_request_success
  end

  context "with an appropriate role" do
    it "can create a quota from a tenant" do
      api_basic_authorize action_identifier(:quotas, :create, :subcollection_actions, :post)

      tenant = FactoryGirl.create(:tenant, :parent => root_tenant)

      expect do
        run_post "/api/tenants/#{tenant.id}/quotas/", :name => :cpu_allocated, :value => 1
      end.to change(TenantQuota, :count).by(1)

      expect_request_success
    end

    it "can update a quota from a tenant with POST" do
      api_basic_authorize action_identifier(:quotas, :edit, :subresource_actions, :post)

      tenant = FactoryGirl.create(:tenant, :parent => root_tenant)
      quota = FactoryGirl.create(:tenant_quota, :tenant_id => tenant.id, :name => :cpu_allocated, :value => 1)

      options = {:value => 5}

      run_post "/api/tenants/#{tenant.id}/quotas/#{quota.id}", gen_request(:edit, options)

      expect_request_success
      quota.reload
      expect(quota.value).to eq(5)
    end

    it "can update a quota from a tenant with PUT" do
      api_basic_authorize action_identifier(:quotas, :edit, :subresource_actions, :put)

      tenant = FactoryGirl.create(:tenant, :parent => root_tenant)
      quota = FactoryGirl.create(:tenant_quota, :tenant_id => tenant.id, :name => :cpu_allocated, :value => 1)

      options = {:value => 5}

      run_put "/api/tenants/#{tenant.id}/quotas/#{quota.id}", options

      expect_request_success
      quota.reload
      expect(quota.value).to eq(5)
    end

    it "can update multiple quotas from a tenant with POST" do
      api_basic_authorize action_identifier(:quotas, :edit, :subcollection_actions, :post)
      tenant = FactoryGirl.create(:tenant, :parent => root_tenant)
      quota_1 = FactoryGirl.create(:tenant_quota, :tenant_id => tenant.id, :name => :cpu_allocated, :value => 1)
      quota_2 = FactoryGirl.create(:tenant_quota, :tenant_id => tenant.id, :name => :mem_allocated, :value => 2)

      options = [
        {"href" => "/api/tenants/#{tenant.id}/quotas/#{quota_1.id}", "value" => 3},
        {"href" => "/api/tenants/#{tenant.id}/quotas/#{quota_2.id}", "value" => 4},
      ]

      run_post "/api/tenants/#{tenant.id}/quotas/", gen_request(:edit, options)

      expect_request_success
      expect_results_to_match_hash(
        "results",
        [{"id" => quota_1.id, "value" => 3},
         {"id" => quota_2.id, "value" => 4}]
      )
      expect(quota_1.reload.value).to eq(3)
      expect(quota_2.reload.value).to eq(4)
    end

    it "can delete a quota from a tenant with POST" do
      api_basic_authorize action_identifier(:quotas, :delete, :subresource_actions, :post)

      tenant = FactoryGirl.create(:tenant, :parent => root_tenant)
      quota = FactoryGirl.create(:tenant_quota, :tenant_id => tenant.id, :name => :cpu_allocated, :value => 1)

      expect do
        run_post "/api/tenants/#{tenant.id}/quotas/#{quota.id}", gen_request(:delete)
      end.to change(TenantQuota, :count).by(-1)

      expect_request_success
    end

    it "can delete a quota from a tenant with DELETE" do
      api_basic_authorize action_identifier(:quotas, :delete, :subresource_actions, :delete)

      tenant = FactoryGirl.create(:tenant, :parent => root_tenant)
      quota = FactoryGirl.create(:tenant_quota, :tenant_id => tenant.id, :name => :cpu_allocated, :value => 1)

      expect do
        run_delete "/api/tenants/#{tenant.id}/quotas/#{quota.id}", gen_request(:delete)
      end.to change(TenantQuota, :count).by(-1)

      expect_request_success_with_no_content
    end

    it "can delete multiple quotas from a tenant with POST" do
      api_basic_authorize action_identifier(:quotas, :delete, :subcollection_actions, :post)

      tenant = FactoryGirl.create(:tenant, :parent => root_tenant)
      quota_1 = FactoryGirl.create(:tenant_quota, :tenant_id => tenant.id, :name => :cpu_allocated, :value => 1)
      quota_2 = FactoryGirl.create(:tenant_quota, :tenant_id => tenant.id, :name => :mem_allocated, :value => 2)

      options = [
        {"href" => "/api/tenants/#{tenant.id}/quotas/#{quota_1.id}"},
        {"href" => "/api/tenants/#{tenant.id}/quotas/#{quota_2.id}"}
      ]

      expect do
        run_post "/api/tenants/#{tenant.id}/quotas/", gen_request(:delete, options)
      end.to change(TenantQuota, :count).by(-2)

      expect_request_success
    end
  end

  context "without an appropriate role" do
    it "will not create a tenant quota" do
      api_basic_authorize

      tenant = FactoryGirl.create(:tenant, :parent => root_tenant)

      expect do
        run_post "/api/tenants/#{tenant.id}/quotas/", :name => :cpu_allocated, :value => 1
      end.not_to change(TenantQuota, :count)

      expect_request_forbidden
    end

    it "will not update a tenant quota with POST" do
      api_basic_authorize

      tenant = FactoryGirl.create(:tenant, :parent => root_tenant)
      quota = FactoryGirl.create(:tenant_quota, :tenant_id => tenant.id, :name => :cpu_allocated, :value => 1)

      options = {:value => 5}

      run_post "/api/tenants/#{tenant.id}/quotas/#{quota.id}", gen_request(:edit, options)

      expect_request_forbidden
      quota.reload
      expect(quota.value).to eq(1)
    end

    it "will not update a tenant quota with PUT" do
      api_basic_authorize

      tenant = FactoryGirl.create(:tenant, :parent => root_tenant)
      quota = FactoryGirl.create(:tenant_quota, :tenant_id => tenant.id, :name => :cpu_allocated, :value => 1)

      options = {:value => 5}

      run_put "/api/tenants/#{tenant.id}/quotas/#{quota.id}", options

      expect_request_forbidden
      quota.reload
      expect(quota.value).to eq(1)
    end

    it "will not update multiple tenant quotas with POST" do
      api_basic_authorize

      tenant = FactoryGirl.create(:tenant, :parent => root_tenant)
      quota_1 = FactoryGirl.create(:tenant_quota, :tenant_id => tenant.id, :name => :cpu_allocated, :value => 1)
      quota_2 = FactoryGirl.create(:tenant_quota, :tenant_id => tenant.id, :name => :mem_allocated, :value => 2)

      options = [
        {"href" => "/api/tenants/#{tenant.id}/quotas/#{quota_1.id}"},
        {"href" => "/api/tenants/#{tenant.id}/quotas/#{quota_2.id}"}
      ]

      run_post "/api/tenants/#{tenant.id}/quotas/", gen_request(:edit, options)

      expect_request_forbidden
      expect(quota_1.reload.value).to eq(1)
      expect(quota_2.reload.value).to eq(2)
    end

    it "will not delete a tenant quota with POST" do
      api_basic_authorize

      tenant = FactoryGirl.create(:tenant, :parent => root_tenant)
      quota = FactoryGirl.create(:tenant_quota, :tenant_id => tenant.id, :name => :cpu_allocated, :value => 1)

      expect do
        run_post "/api/tenants/#{tenant.id}/quotas/#{quota.id}", gen_request(:delete)
      end.not_to change(TenantQuota, :count)

      expect_request_forbidden
    end

    it "will not delete a tenant quota with DELETE" do
      api_basic_authorize

      tenant = FactoryGirl.create(:tenant, :parent => root_tenant)
      quota = FactoryGirl.create(:tenant_quota, :tenant_id => tenant.id, :name => :cpu_allocated, :value => 1)

      expect do
        run_delete "/api/tenants/#{tenant.id}/quotas/#{quota.id}"
      end.not_to change(TenantQuota, :count)

      expect_request_forbidden
    end

    it "will not update multiple tenants with POST" do
      api_basic_authorize

      tenant = FactoryGirl.create(:tenant, :parent => root_tenant)
      quota_1 = FactoryGirl.create(:tenant_quota, :tenant_id => tenant.id, :name => :cpu_allocated, :value => 1)
      quota_2 = FactoryGirl.create(:tenant_quota, :tenant_id => tenant.id, :name => :mem_allocated, :value => 2)

      options = [
        {"href" => "/api/tenants/#{tenant.id}/quotas/#{quota_1.id}"},
        {"href" => "/api/tenants/#{tenant.id}/quotas/#{quota_2.id}"}
      ]

      expect do
        run_post "/api/tenants/#{tenant.id}/quotas/", gen_request(:delete, options)
      end.not_to change(TenantQuota, :count)

      expect_request_forbidden
    end
  end
end
