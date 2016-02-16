#
# Rest API Request Tests - set_ownership action specs
#
# set_ownership action availability to:
# - Services                /api/services/:id
# - Vms                     /api/vms/:id
# - Templates               /api/templates/:id
#
describe ApiController do
  include_context "api request specs"

  def expect_set_ownership_success(object, href, user = nil, group = nil)
    expect_single_action_result(:success => true, :message => "setting ownership", :href => href)
    expect(object.reload.evm_owner).to eq(user)  if user
    expect(object.reload.miq_group).to eq(group) if group
  end

  context "Service set_ownership action" do
    let(:svc) { FactoryGirl.create(:service, :name => "svc", :description => "svc description") }

    it "to an invalid service" do
      api_basic_authorize action_identifier(:services, :set_ownership)

      run_post(services_url(999_999), gen_request(:set_ownership, "owner" => {"id" => 1}))

      expect_resource_not_found
    end

    it "without appropriate action role" do
      api_basic_authorize

      run_post(services_url(svc.id), gen_request(:set_ownership, "owner" => {"id" => 1}))

      expect_request_forbidden
    end

    it "with missing owner or group" do
      api_basic_authorize action_identifier(:services, :set_ownership)

      run_post(services_url(svc.id), gen_request(:set_ownership))

      expect_bad_request("Must specify an owner or group")
    end

    it "with invalid owner" do
      api_basic_authorize action_identifier(:services, :set_ownership)

      run_post(services_url(svc.id), gen_request(:set_ownership, "owner" => {"id" => 999_999}))

      expect_single_action_result(:success => false, :message => /.*/, :href => services_url(svc.id))
    end

    it "to a service" do
      api_basic_authorize action_identifier(:services, :set_ownership)

      run_post(services_url(svc.id), gen_request(:set_ownership, "owner" => {"userid" => api_config(:user)}))

      expect_set_ownership_success(svc, services_url(svc.id), @user)
    end

    it "by owner name to a service" do
      api_basic_authorize action_identifier(:services, :set_ownership)

      run_post(services_url(svc.id), gen_request(:set_ownership, "owner" => {"name" => @user.name}))

      expect_set_ownership_success(svc, services_url(svc.id), @user)
    end

    it "by owner href to a service" do
      api_basic_authorize action_identifier(:services, :set_ownership)

      run_post(services_url(svc.id), gen_request(:set_ownership, "owner" => {"href" => users_url(@user.id)}))

      expect_set_ownership_success(svc, services_url(svc.id), @user)
    end

    it "by owner id to a service" do
      api_basic_authorize action_identifier(:services, :set_ownership)

      run_post(services_url(svc.id), gen_request(:set_ownership, "owner" => {"id" => @user.id}))

      expect_set_ownership_success(svc, services_url(svc.id), @user)
    end

    it "by group id to a service" do
      api_basic_authorize action_identifier(:services, :set_ownership)

      run_post(services_url(svc.id), gen_request(:set_ownership, "group" => {"id" => @group.id}))

      expect_set_ownership_success(svc, services_url(svc.id), nil, @group)
    end

    it "by group description to a service" do
      api_basic_authorize action_identifier(:services, :set_ownership)

      run_post(services_url(svc.id), gen_request(:set_ownership, "group" => {"description" => @group.description}))

      expect_set_ownership_success(svc, services_url(svc.id), nil, @group)
    end

    it "with owner and group to a service" do
      api_basic_authorize action_identifier(:services, :set_ownership)

      run_post(services_url(svc.id), gen_request(:set_ownership, "owner" => {"userid" => api_config(:user)}))

      expect_set_ownership_success(svc, services_url(svc.id), @user)
    end

    it "to multiple services" do
      api_basic_authorize action_identifier(:services, :set_ownership)

      svc1 = FactoryGirl.create(:service, :name => "svc1", :description => "svc1 description")
      svc2 = FactoryGirl.create(:service, :name => "svc2", :description => "svc2 description")

      svc_urls = [services_url(svc1.id), services_url(svc2.id)]
      run_post(services_url, gen_request(:set_ownership, {"owner" => {"userid" => api_config(:user)}}, *svc_urls))

      expect_multiple_action_result(2)
      expect_result_resources_to_include_hrefs("results", svc_urls)
      expect(svc1.reload.evm_owner).to eq(@user)
      expect(svc2.reload.evm_owner).to eq(@user)
    end
  end

  context "Vms set_ownership action" do
    let(:vm) { FactoryGirl.create(:vm, :name => "vm", :description => "vm description") }

    it "to an invalid vm" do
      api_basic_authorize action_identifier(:vms, :set_ownership)

      run_post(vms_url(999_999), gen_request(:set_ownership, "owner" => {"id" => 1}))

      expect_resource_not_found
    end

    it "without appropriate action role" do
      api_basic_authorize

      run_post(vms_url(vm.id), gen_request(:set_ownership, "owner" => {"id" => 1}))

      expect_request_forbidden
    end

    it "with missing owner or group" do
      api_basic_authorize action_identifier(:vms, :set_ownership)

      run_post(vms_url(vm.id), gen_request(:set_ownership))

      expect_bad_request("Must specify an owner or group")
    end

    it "with invalid owner" do
      api_basic_authorize action_identifier(:vms, :set_ownership)

      run_post(vms_url(vm.id), gen_request(:set_ownership, "owner" => {"id" => 999_999}))

      expect_single_action_result(:success => false, :message => /.*/, :href => vms_url(vm.id))
    end

    it "to a vm" do
      api_basic_authorize action_identifier(:vms, :set_ownership)

      run_post(vms_url(vm.id), gen_request(:set_ownership, "owner" => {"userid" => api_config(:user)}))

      expect_set_ownership_success(vm, vms_url(vm.id), @user)
    end

    it "by owner name to a vm" do
      api_basic_authorize action_identifier(:vms, :set_ownership)

      run_post(vms_url(vm.id), gen_request(:set_ownership, "owner" => {"name" => @user.name}))

      expect_set_ownership_success(vm, vms_url(vm.id), @user)
    end

    it "by owner href to a vm" do
      api_basic_authorize action_identifier(:vms, :set_ownership)

      run_post(vms_url(vm.id), gen_request(:set_ownership, "owner" => {"href" => users_url(@user.id)}))

      expect_set_ownership_success(vm, vms_url(vm.id), @user)
    end

    it "by owner id to a vm" do
      api_basic_authorize action_identifier(:vms, :set_ownership)

      run_post(vms_url(vm.id), gen_request(:set_ownership, "owner" => {"id" => @user.id}))

      expect_set_ownership_success(vm, vms_url(vm.id), @user)
    end

    it "by group id to a vm" do
      api_basic_authorize action_identifier(:vms, :set_ownership)

      run_post(vms_url(vm.id), gen_request(:set_ownership, "group" => {"id" => @group.id}))

      expect_set_ownership_success(vm, vms_url(vm.id), nil, @group)
    end

    it "by group description to a vm" do
      api_basic_authorize action_identifier(:vms, :set_ownership)

      run_post(vms_url(vm.id), gen_request(:set_ownership, "group" => {"description" => @group.description}))

      expect_set_ownership_success(vm, vms_url(vm.id), nil, @group)
    end

    it "with owner and group to a vm" do
      api_basic_authorize action_identifier(:vms, :set_ownership)

      run_post(vms_url(vm.id), gen_request(:set_ownership, "owner" => {"userid" => api_config(:user)}))

      expect_set_ownership_success(vm, vms_url(vm.id), @user)
    end

    it "to multiple vms" do
      api_basic_authorize action_identifier(:vms, :set_ownership)

      vm1 = FactoryGirl.create(:vm, :name => "vm1", :description => "vm1 description")
      vm2 = FactoryGirl.create(:vm, :name => "vm2", :description => "vm2 description")

      vm_urls = [vms_url(vm1.id), vms_url(vm2.id)]
      run_post(vms_url, gen_request(:set_ownership, {"owner" => {"userid" => api_config(:user)}}, *vm_urls))

      expect_multiple_action_result(2)
      expect_result_resources_to_include_hrefs("results", vm_urls)
      expect(vm1.reload.evm_owner).to eq(@user)
      expect(vm2.reload.evm_owner).to eq(@user)
    end
  end

  context "Template set_ownership action" do
    let(:template) { FactoryGirl.create(:template_vmware, :name => "template") }

    it "to an invalid template" do
      api_basic_authorize action_identifier(:templates, :set_ownership)

      run_post(templates_url(999_999), gen_request(:set_ownership, "owner" => {"id" => 1}))

      expect_resource_not_found
    end

    it "without appropriate action role" do
      api_basic_authorize

      run_post(templates_url(template.id), gen_request(:set_ownership, "owner" => {"id" => 1}))

      expect_request_forbidden
    end

    it "with missing owner or group" do
      api_basic_authorize action_identifier(:templates, :set_ownership)

      run_post(templates_url(template.id), gen_request(:set_ownership))

      expect_bad_request("Must specify an owner or group")
    end

    it "with invalid owner" do
      api_basic_authorize action_identifier(:templates, :set_ownership)

      run_post(templates_url(template.id), gen_request(:set_ownership, "owner" => {"id" => 999_999}))

      expect_single_action_result(:success => false, :message => /.*/, :href => templates_url(template.id))
    end

    it "to a template" do
      api_basic_authorize action_identifier(:templates, :set_ownership)

      run_post(templates_url(template.id), gen_request(:set_ownership, "owner" => {"userid" => api_config(:user)}))

      expect_set_ownership_success(template, templates_url(template.id), @user)
    end

    it "by owner name to a template" do
      api_basic_authorize action_identifier(:templates, :set_ownership)

      run_post(templates_url(template.id), gen_request(:set_ownership, "owner" => {"name" => @user.name}))

      expect_set_ownership_success(template, templates_url(template.id), @user)
    end

    it "by owner href to a template" do
      api_basic_authorize action_identifier(:templates, :set_ownership)

      run_post(templates_url(template.id), gen_request(:set_ownership, "owner" => {"href" => users_url(@user.id)}))

      expect_set_ownership_success(template, templates_url(template.id), @user)
    end

    it "by owner id to a template" do
      api_basic_authorize action_identifier(:templates, :set_ownership)

      run_post(templates_url(template.id), gen_request(:set_ownership, "owner" => {"id" => @user.id}))

      expect_set_ownership_success(template, templates_url(template.id), @user)
    end

    it "by group id to a template" do
      api_basic_authorize action_identifier(:templates, :set_ownership)

      run_post(templates_url(template.id), gen_request(:set_ownership, "group" => {"id" => @group.id}))

      expect_set_ownership_success(template, templates_url(template.id), nil, @group)
    end

    it "by group description to a template" do
      api_basic_authorize action_identifier(:templates, :set_ownership)

      run_post(templates_url(template.id),
               gen_request(:set_ownership, "group" => {"description" => @group.description}))

      expect_set_ownership_success(template, templates_url(template.id), nil, @group)
    end

    it "with owner and group to a template" do
      api_basic_authorize action_identifier(:templates, :set_ownership)

      run_post(templates_url(template.id), gen_request(:set_ownership, "owner" => {"userid" => api_config(:user)}))

      expect_set_ownership_success(template, templates_url(template.id), @user)
    end

    it "to multiple templates" do
      api_basic_authorize action_identifier(:templates, :set_ownership)

      template1 = FactoryGirl.create(:template_vmware, :name => "template1")
      template2 = FactoryGirl.create(:template_vmware, :name => "template2")

      template_urls = [templates_url(template1.id), templates_url(template2.id)]
      run_post(templates_url, gen_request(:set_ownership, {"owner" => {"userid" => api_config(:user)}}, *template_urls))

      expect_multiple_action_result(2)
      expect_result_resources_to_include_hrefs("results", template_urls)
      expect(template1.reload.evm_owner).to eq(@user)
      expect(template2.reload.evm_owner).to eq(@user)
    end
  end
end
