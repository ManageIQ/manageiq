RSpec.describe ServiceOrchestration do
  let(:manager_by_setter)  { FactoryBot.create(:ems_amazon) }
  let(:template_by_setter) { FactoryBot.create(:orchestration_template) }
  let(:manager_by_dialog)  { FactoryBot.create(:ems_amazon) }
  let(:template_by_dialog) { FactoryBot.create(:orchestration_template) }
  let(:manager_in_st)      { FactoryBot.create(:ems_amazon) }
  let(:template_in_st)     { FactoryBot.create(:orchestration_template) }
  let(:deployed_stack)     { FactoryBot.create(:orchestration_stack_amazon) }

  let(:service_template) do
    FactoryBot.create(:service_template_orchestration,
                      :orchestration_manager  => manager_in_st,
                      :orchestration_template => template_in_st)
  end

  let(:dialog_options) do
    {
      'dialog_stack_template'                 => template_by_dialog.id,
      'dialog_stack_manager'                  => manager_by_dialog.id,
      'dialog_stack_name'                     => 'test123',
      'dialog_stack_onfailure'                => 'ROLLBACK',
      'dialog_stack_timeout'                  => '30',
      'dialog_param_InstanceType'             => 'cg1.4xlarge',
      'password::dialog_param_DBRootPassword' => 'v2:{c2XR8/Yl1CS0phoOVMNU9w==}',
      :dialog_param_key_in_symbol             => 'not_expected'
    }
  end

  let(:service) do
    FactoryBot.create(:service_orchestration,
                      :service_template       => service_template,
                      :orchestration_manager  => manager_in_st,
                      :orchestration_template => template_in_st,
                      :evm_owner              => FactoryBot.create(:user),
                      :miq_group              => FactoryBot.create(:miq_group))
  end

  let(:service_with_dialog_options) do
    service.options = {:dialog => dialog_options}
    service
  end

  let(:service_with_deployed_stack) do
    service.add_resource(deployed_stack)
    service
  end

  describe "#stack_name" do
    it "gets stack name from dialog options" do
      expect(service_with_dialog_options.stack_name).to eq('test123')
    end

    it "gets stack name from overridden value" do
      service_with_dialog_options.stack_name = "new_name"
      expect(service_with_dialog_options.stack_name).to eq("new_name")
    end
  end

  describe "#add_resource" do
    it "doesn't allow service to be added" do
      expect { service_with_dialog_options.add_resource(FactoryBot.create(:service), {}) }.to raise_error(/Service Orchestration subclass does not support add_resource for/)
    end

    it "allows stack to be added" do
      service_with_dialog_options.add_resource(FactoryBot.create(:orchestration_stack))
      expect(service_with_dialog_options.service_resources.pluck(:resource_type)).to include("OrchestrationStack", "OrchestrationTemplate")
    end
  end

  describe "#my_zone" do
    it "deployed stack, takes the zone from ext_management_system" do
      deployed_stack.ext_management_system = manager_by_setter
      expect(deployed_stack.my_zone).to eq(manager_by_setter.my_zone)
    end

    it "deployed stack, returns nil zone if ext_management_system is not valid" do
      expect(deployed_stack.my_zone).to be_nil
    end

    it "service, takes the zone from orchestration_manager" do
      ems = FactoryBot.create(:ems_amazon, :zone => FactoryBot.create(:zone))
      deployed_stack.direct_vms << FactoryBot.create(:vm_amazon, :ext_management_system => ems)
      expect(service_with_deployed_stack.my_zone).to eq(service.orchestration_manager.my_zone)
    end

    it "service, takes the zone from VM ext_management_system if no orchestration_manager" do
      ems = FactoryBot.create(:ems_amazon, :zone => FactoryBot.create(:zone))
      deployed_stack.direct_vms << FactoryBot.create(:vm_amazon, :ext_management_system => ems)
      service.orchestration_manager = nil
      expect(service_with_deployed_stack.my_zone).to eq(service_with_deployed_stack.vms.first.ext_management_system.my_zone)
    end

    it "service, returns nil zone if no orchestration_manager and no VMs" do
      service.orchestration_manager = nil
      expect(service_with_deployed_stack.my_zone).to be_nil
    end
  end

  describe "#stack_options" do
    before do
      allow_any_instance_of(ManageIQ::Providers::Amazon::CloudManager::OrchestrationServiceOptionConverter).to(
        receive(:stack_create_options).and_return(dialog_options)
      )
    end

    it "gets stack options set by dialog" do
      expect(service_with_dialog_options.stack_options).to eq(dialog_options)
    end

    it "can access options key as string" do
      expect(service_with_dialog_options.stack_options["dialog_stack_name"]).to eq('test123')
    end

    it "can access options key as symbol" do
      expect(service_with_dialog_options.stack_options[:dialog_param_key_in_symbol]).to eq('not_expected')
    end

    context "cloud tenant option" do
      it "parses a valid tenant option" do
        dialog_options['dialog_tenant_name'] = 'abc'
        expect(service_with_dialog_options.stack_options).to include(:tenant_name => 'abc')
      end

      it "excludes the tenant option when it is nil" do
        dialog_options['dialog_tenant_name'] = nil
        expect(service_with_dialog_options.stack_options).not_to include(:tenant_name)
      end

      it "excludes thetenant option when it is empty" do
        dialog_options['dialog_tenant_name'] = ''
        expect(service_with_dialog_options.stack_options).not_to include(:tenant_name)
      end
    end

    it "gets stack options from overridden values" do
      new_options = {"any_key" => "any_value"}
      service_with_dialog_options.stack_options = new_options
      expect(service_with_dialog_options.stack_options).to eq(new_options)
    end

    it "encrypts password when saves to DB" do
      new_options = {:parameters => {"my_password" => "secret"}}
      service_with_dialog_options.stack_options = new_options
      expect(service_with_dialog_options.options[:create_options][:parameters]["my_password"]).to eq(ManageIQ::Password.encrypt("secret"))
    end

    context "overwrite selections for orchestration manager and template" do
      it "takes the orchestration template from service template by default" do
        expect(service_with_dialog_options.orchestration_template).to eq(template_in_st)
      end

      it "takes the orchestration manager from service template by default" do
        expect(service_with_dialog_options.orchestration_manager).to eq(manager_in_st)
      end

      it "prefers the orchestration template set by dialog" do
        service_with_dialog_options.stack_options
        expect(service_with_dialog_options.orchestration_template).to eq(template_by_dialog)
      end

      it "prefers the orchestration manager set by dialog" do
        service_with_dialog_options.stack_options
        expect(service_with_dialog_options.orchestration_manager).to eq(manager_by_dialog)
      end

      it "prefers the orchestration template set by setter" do
        service.orchestration_template = template_by_setter
        service_with_dialog_options.stack_options
        expect(service_with_dialog_options.orchestration_template).to eq(template_by_setter)
      end

      it "prefers the orchestration manager set by setter" do
        service.orchestration_manager = manager_by_setter
        service_with_dialog_options.stack_options
        expect(service_with_dialog_options.orchestration_manager).to eq(manager_by_setter)
      end
    end
  end

  describe '#deploy_orchestration_stack' do
    it 'calls OrchestrationTemplateRunner' do
      job = double(:job, :id => 1, :orchestration_stack => FactoryBot.create(:orchestration_stack))
      allow(job).to receive(:signal).with(:start)
      allow(service_with_dialog_options).to receive(:wait_on_orchestration_stack)
      allow(ManageIQ::Providers::CloudManager::OrchestrationTemplateRunner).to receive(:create_job) do |options|
        expect(options).to include(
          :orchestration_manager_id  => manager_by_dialog.id,
          :stack_name                => service_with_dialog_options.stack_name,
          :orchestration_template_id => template_by_dialog.id,
          :execution_ttl             => 10,
          :zone                      => service_with_dialog_options.my_zone
        )
        expect(options[:create_options]).to include(
          :parameters         => {
            "InstanceType"   => "cg1.4xlarge",
            "DBRootPassword" => "admin",
            "key_in_symbol"  => "not_expected"
          },
          :on_failure         => "ROLLBACK",
          :timeout_in_minutes => 30
        )
      end.and_return(job)

      service_with_dialog_options.options[:execution_ttl] = 10
      service_with_dialog_options.deploy_orchestration_stack
    end

    it 'raises runtime error when job finishes with pre-existing stack' do
      job = double(:job, :id => 1, :status => 'error', :orchestration_stack => nil)
      allow(job).to receive(:signal).with(:start)
      allow(ManageIQ::Providers::CloudManager::OrchestrationTemplateRunner).to receive(:create_job).and_return(job)
      expect { service_with_dialog_options.deploy_orchestration_stack }.to raise_error(RuntimeError, /Orchestration template runner finished with error/)
    end
  end

  describe '#update_orchestration_stack' do
    let(:reconfigurable_service) do
      @stack = FactoryBot.create(:orchestration_stack)
      service_template = FactoryBot.create(:service_template_orchestration)
      service_template.orchestration_template = template_by_setter

      service.service_template = service_template
      service.orchestration_manager = manager_by_setter
      service.add_resource(@stack)
      service.update_options = service.build_stack_options_from_dialog(dialog_options)
      service
    end

    it 'calls OrchestrationTemplateRunner' do
      job = FactoryBot.create(:job)
      allow(job).to receive(:signal).with(:reconfigure)
      allow(ManageIQ::Providers::CloudManager::OrchestrationTemplateRunner).to receive(:create_job) do |options|
        expect(options[:update_options][:parameters]).to include(
          'InstanceType'   => 'cg1.4xlarge',
          'DBRootPassword' => 'admin',
          'key_in_symbol'  => 'not_expected'
        )
        expect(options).to include(
          :orchestration_stack_id    => @stack.id,
          :orchestration_template_id => template_by_setter.id,
          :execution_ttl             => 10,
          :zone                      => reconfigurable_service.my_zone
        )
      end.and_return(job)
      reconfigurable_service.options[:reconfigure_automate_timeout] = 10
      reconfigurable_service.update_orchestration_stack
    end
  end

  describe '#orchestration_stack_status' do
    it 'returns an error if stack runner job has never been created' do
      status, _message = service.orchestration_stack_status
      expect(status).to eq('deploy_failed')
    end

    it 'return an error if stack runner finishes with an error' do
      stack_job = double(:state => 'finished', :status => 'error', :message => 'deploy error')
      allow(service_with_deployed_stack).to receive(:orchestration_runner_job).and_return(stack_job)

      status, message = service_with_deployed_stack.orchestration_stack_status
      expect(status).to eq('deploy_failed')
      expect(message).to eq('deploy error')
    end

    it 'returns current stack status through stack runner' do
      stack_job = double(:orchestration_stack_status => 'create_complete', :orchestration_stack_message => 'no error', :state => 'finished', :status => 'ok')
      allow(service_with_deployed_stack).to receive(:orchestration_runner_job).and_return(stack_job)

      status, message = service_with_deployed_stack.orchestration_stack_status
      expect(status).to eq('create_complete')
      expect(message).to eq('no error')
    end

    it "returns deploy_active when stack status not set in stack job's options" do
      stack_job = double(:state => 'active', :status => 'ok', :orchestration_stack_status => nil)
      allow(service_with_deployed_stack).to receive(:orchestration_runner_job).and_return(stack_job)

      status, message = service_with_deployed_stack.orchestration_stack_status
      expect(status).to eq('deploy_active')
      expect(message).to eq('waiting for the orchestration stack status')
    end
  end

  describe '#all_vms' do
    it 'returns all vms from a deployed stack' do
      vm1 = FactoryBot.create(:vm_amazon)
      vm2 = FactoryBot.create(:vm_amazon)

      child_stack = FactoryBot.create(:orchestration_stack_amazon, :parent => deployed_stack)
      deployed_stack.direct_vms << vm1
      child_stack.direct_vms << vm2

      expect(service_with_deployed_stack.all_vms.map(&:id)).to match_array([vm1, vm2].map(&:id))
      expect(service_with_deployed_stack.direct_vms.map(&:id)).to match_array([vm1, vm2].map(&:id))
      expect(service_with_deployed_stack.indirect_vms.map(&:id)).to match_array([vm2].map(&:id))
      expect(service_with_deployed_stack.vms.map(&:id)).to match_array([vm1, vm2].map(&:id))
    end

    it 'returns no vm if no stack is deployed' do
      expect(service.all_vms).to be_empty
      expect(service.direct_vms).to be_empty
      expect(service.indirect_vms).to be_empty
      expect(service.vms).to be_empty
    end
  end

  describe '#post_provision_configure' do
    before do
      allow(ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack).to receive(:raw_create_stack).and_return("ems_ref")
      @resulting_stack = ManageIQ::Providers::CloudManager::OrchestrationStack.create_stack(
        service.orchestration_manager, service.stack_name, service.orchestration_template, service.stack_options
      )
      service.update(:options => service.options.merge!(:orchestration_stack => @resulting_stack.attributes.compact.except(:id)))
      allow(service).to receive(:orchestration_stack).and_return(@resulting_stack)
      service.miq_request_task = FactoryBot.create(:service_template_provision_task)
    end

    it 'sets owners for all vms included in the stack' do
      vms = [FactoryBot.create(:vm_amazon), FactoryBot.create(:vm_amazon)]
      @resulting_stack.direct_vms.push(*vms)

      service.post_provision_configure
      vms.each do |vm|
        vm.reload
        expect(vm.evm_owner).to eq(service.evm_owner)
        expect(vm.miq_group).to eq(service.miq_group)
      end
    end

    it 'adds the provisioned stack to service resources' do
      service.post_provision_configure
      expect(service.service_resources.find_by(:resource_type => 'OrchestrationStack').resource).to eq(@resulting_stack)
    end

    it 'reconnects cataloged stack with the orchestration template' do
      # purposely disconnect the template
      @resulting_stack.update!(:orchestration_template => nil)

      service.post_provision_configure
      @resulting_stack.reload
      expect(@resulting_stack.orchestration_template).to eq(template_in_st)
    end
  end
end
