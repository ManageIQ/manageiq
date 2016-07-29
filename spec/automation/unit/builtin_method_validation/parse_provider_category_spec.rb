describe "parse_provider_category" do
  let(:infra_ems)       { FactoryGirl.create(:ems_vmware_with_authentication) }
  let(:infra_vm)        { FactoryGirl.create(:vm_vmware, :ems_id => infra_ems.id, :evm_owner => user) }
  let(:migrate_request) { FactoryGirl.create(:vm_migrate_request, :requester => user) }
  let(:user)            { FactoryGirl.create(:user_with_group) }
  let(:inst)            { "/System/Process/parse_provider_category" }
  let(:miq_host_provision) do
    FactoryGirl.create(:miq_host_provision, :provision_type => 'host_pxe_install', :state => 'pending', :status => 'Ok')
  end

  let(:infra_miq_request_task) do
    FactoryGirl.create(:miq_request_task, :miq_request => migrate_request, :source => infra_vm)
  end

  let(:infra_vm_template) do
    FactoryGirl.create(:template_microsoft,
                       :name                  => "template1",
                       :ext_management_system => infra_ems)
  end

  let(:infra_miq_provision) do
    FactoryGirl.create(:miq_provision_microsoft,
                       :options => {:src_vm_id => infra_vm_template.id},
                       :userid  => user.userid,
                       :status  => 'Ok')
  end

  let(:infra_miq_provision_request) do
    FactoryGirl.create(:miq_provision_request,
                       :provision_type => 'template',
                       :state => 'pending', :status => 'Ok',
                       :src_vm_id => infra_vm_template.id,
                       :requester => user)
  end

  let(:cloud_ems) { FactoryGirl.create(:ems_amazon_with_authentication) }
  let(:cloud_vm)  { FactoryGirl.create(:vm_amazon, :ems_id => cloud_ems.id, :evm_owner => user) }
  let(:stack)     { FactoryGirl.create(:orchestration_stack_amazon, :ext_management_system => cloud_ems) }

  let(:cloud_vm_template) do
    FactoryGirl.create(:template_amazon,
                       :name                  => "template1",
                       :ext_management_system => cloud_ems)
  end

  let(:cloud_miq_provision) do
    FactoryGirl.create(:miq_provision_amazon,
                       :options => {:src_vm_id => cloud_vm_template.id},
                       :userid  => user.userid,
                       :state   => 'active',
                       :status  => 'Ok')
  end

  def prepend_namespace(ws)
    dom_search = ws.instance_variable_get('@dom_search')
    dom_search.instance_variable_get('@prepend_namespace')
  end

  context "#parse_provider_category for cloud objects" do
    it "for VM" do
      ws = MiqAeEngine.instantiate("#{inst}?Vm::vm=#{cloud_vm.id}", user)
      expect(ws.root["ae_provider_category"]).to eq("cloud")
      expect(prepend_namespace(ws)).to eq("amazon")
    end

    it "for orchestration stack" do
      ws = MiqAeEngine.instantiate("#{inst}?OrchestrationStack::orchestration_stack=#{stack.id}", user)
      expect(ws.root["ae_provider_category"]).to eq("cloud")
      expect(prepend_namespace(ws)).to match(/amazon/i)
    end

    it "for miq_provision" do
      ws = MiqAeEngine.instantiate("#{inst}?MiqProvision::miq_provision=#{cloud_miq_provision.id}", user)
      expect(ws.root["ae_provider_category"]).to eq("cloud")
      expect(prepend_namespace(ws)).to eq("amazon")
    end
  end

  context "#parse_provider_category for infrastructure objects" do
    it "for miq_provision" do
      ws = MiqAeEngine.instantiate("#{inst}?MiqProvision::miq_provision=#{infra_miq_provision.id}", user)
      expect(ws.root["ae_provider_category"]).to eq("infrastructure")
      expect(prepend_namespace(ws)).to eq("microsoft")
    end

    it "for miq_request" do
      ws = MiqAeEngine.instantiate("#{inst}?MiqRequest::miq_request=#{infra_miq_provision_request.id}", user)
      expect(ws.root["ae_provider_category"]).to eq("infrastructure")
      expect(prepend_namespace(ws)).to eq("microsoft")
    end

    it "for vm_migrate_request" do
      ws = MiqAeEngine.instantiate("#{inst}?MiqRequestTask::vm_migrate_task=#{infra_miq_request_task.id}", user)
      expect(ws.root["ae_provider_category"]).to eq("infrastructure")
      expect(prepend_namespace(ws)).to eq("vmware")
    end

    it "for vm_host_provision" do
      ws = MiqAeEngine.instantiate("#{inst}?MiqRequestTask::miq_host_provision=#{miq_host_provision.id}", user)
      expect(ws.root["ae_provider_category"]).to eq("infrastructure")
      expect(prepend_namespace(ws)).to eq("vmware")
    end
  end

  context "#parse_provider_category for platform_category" do
    it "for cloud platform_category" do
      ws = MiqAeEngine.instantiate("#{inst}?platform_category=cloud", user)
      expect(ws.root["ae_provider_category"]).to eq("cloud")
      expect(prepend_namespace(ws)).to be_nil
    end

    it "for infra platform_category" do
      ws = MiqAeEngine.instantiate("#{inst}?platform_category=infra", user)
      expect(ws.root["ae_provider_category"]).to eq("infrastructure")
      expect(prepend_namespace(ws)).to be_nil
    end
  end
end
