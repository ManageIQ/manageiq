describe ServiceOrchestration do
  let(:manager_by_setter)  { FactoryGirl.create(:ems_amazon) }
  let(:template_by_setter) { FactoryGirl.create(:orchestration_template) }
  let(:manager_by_dialog)  { FactoryGirl.create(:ems_amazon) }
  let(:template_by_dialog) { FactoryGirl.create(:orchestration_template) }
  let(:deployed_stack)     { FactoryGirl.create(:orchestration_stack_amazon) }

  let(:dialog_options) do
    {
      'dialog_stack_template'                 => template_by_dialog.id,
      'dialog_stack_manager'                  => manager_by_dialog.id,
      'dialog_stack_name'                     => 'test123',
      'dialog_stack_onfailure'                => 'ROLLBACK',
      'dialog_stack_timeout'                  => '30',
      'dialog_param_InstanceType'             => 'cg1.4xlarge',
      'password::dialog_param_DBRootPassword' => 'v2:{c2XR8/Yl1CS0phoOVMNU9w==}'
    }
  end

  let(:service) do
    FactoryGirl.create(:service_orchestration,
      :evm_owner => FactoryGirl.create(:user),
      :miq_group => FactoryGirl.create(:miq_group))
  end

  let(:service_with_dialog_options) do
    service.options = {:dialog => dialog_options}
    service
  end

  let(:service_mix_dialog_setter) do
    service.orchestration_template = template_by_setter
    service.orchestration_manager = manager_by_setter
    service.options = {:dialog => dialog_options}
    service
  end

  let(:service_with_deployed_stack) do
    service_mix_dialog_setter.add_resource(deployed_stack)
    service_mix_dialog_setter
  end

  context "#stack_name" do
    it "gets stack name from dialog options" do
      expect(service_with_dialog_options.stack_name).to eq('test123')
    end

    it "gets stack name from overridden value" do
      service_with_dialog_options.stack_name = "new_name"
      expect(service_with_dialog_options.stack_name).to eq("new_name")
    end
  end

  context "#stack_options" do
    before do
      allow_any_instance_of(ManageIQ::Providers::Amazon::CloudManager::OrchestrationServiceOptionConverter).to(
        receive(:stack_create_options).and_return(dialog_options))
    end

    it "gets stack options set by dialog" do
      expect(service_with_dialog_options.stack_options).to eq(dialog_options)
    end

    it "gets stack options from overridden values" do
      new_options = {"any_key" => "any_value"}
      service_with_dialog_options.stack_options = new_options
      expect(service_with_dialog_options.stack_options).to eq(new_options)
    end

    it "encrypts password when saves to DB" do
      new_options = {:parameters => {"my_password" => "secret"}}
      service_with_dialog_options.stack_options = new_options
      expect(service_with_dialog_options.options[:create_options][:parameters]["my_password"]).to eq(MiqPassword.encrypt("secret"))
    end

    it "prefers the orchestration template set by dialog" do
      expect(service_mix_dialog_setter.orchestration_template).to eq(template_by_setter)
      service_mix_dialog_setter.stack_options
      expect(service_mix_dialog_setter.orchestration_template).to eq(template_by_dialog)
    end

    it "prefers the orchestration manager set by dialog" do
      expect(service_mix_dialog_setter.orchestration_manager).to eq(manager_by_setter)
      service_mix_dialog_setter.stack_options
      expect(service_mix_dialog_setter.orchestration_manager).to eq(manager_by_dialog)
    end
  end

  context '#deploy_orchestration_stack' do
    it 'creates a stack through cloud manager' do
      allow(ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack).to receive(:raw_create_stack) do |manager, name, template, opts|
        expect(manager).to eq(manager_by_setter)
        expect(name).to eq('test123')
        expect(template).to be_kind_of OrchestrationTemplate
        expect(opts).to be_kind_of Hash
      end

      service_mix_dialog_setter.deploy_orchestration_stack
    end

    it 'always saves options even when the manager fails to create a stack' do
      ProvisionError = MiqException::MiqOrchestrationProvisionError
      allow_any_instance_of(ManageIQ::Providers::Amazon::CloudManager).to receive(:stack_create).and_raise(ProvisionError, 'test failure')

      expect(service_mix_dialog_setter).to receive(:save_create_options)
      expect { service_mix_dialog_setter.deploy_orchestration_stack }.to raise_error(ProvisionError)
    end
  end

  context '#update_orchestration_stack' do
    let(:reconfigurable_service) do
      stack = FactoryGirl.create(:orchestration_stack)
      service_template = FactoryGirl.create(:service_template_orchestration)
      service_template.orchestration_template = template_by_setter

      service.service_template = service_template
      service.orchestration_manager = manager_by_setter
      service.add_resource(stack)
      service.update_options = service.build_stack_options_from_dialog(dialog_options)
      service
    end

    it 'updates a stack through cloud manager' do
      allow_any_instance_of(OrchestrationStack).to receive(:raw_update_stack) do |_instance, new_template, opts|
        expect(opts[:parameters]).to include(
          'InstanceType'   => 'cg1.4xlarge',
          'DBRootPassword' => 'admin'
        )
        expect(new_template).to eq(template_by_setter)
      end
      reconfigurable_service.update_orchestration_stack
    end

    it 'saves update options and encrypts password' do
      expect(reconfigurable_service.options[:update_options][:parameters]['DBRootPassword']).to eq(MiqPassword.encrypt("admin"))
    end
  end

  context '#orchestration_stack_status' do
    it 'returns an error if stack has never been deployed' do
      status, _message = service_mix_dialog_setter.orchestration_stack_status
      expect(status).to eq('check_status_failed')
    end

    it 'returns current stack status through provider' do
      status_obj = ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack::Status.new('CREATE_COMPLETE', 'no error')
      allow(deployed_stack).to receive(:raw_status).and_return(status_obj)

      status, message = service_with_deployed_stack.orchestration_stack_status
      expect(status).to eq('create_complete')
      expect(message).to eq('no error')
    end

    it 'returns an error message when the provider fails to retrieve the status' do
      allow(deployed_stack).to receive(:raw_status).and_raise(MiqException::MiqOrchestrationStatusError, 'test failure')

      status, message = service_with_deployed_stack.orchestration_stack_status
      expect(status).to eq('check_status_failed')
      expect(message).to eq('test failure')
    end
  end

  context '#all_vms' do
    it 'returns all vms from a deployed stack' do
      vm1 = FactoryGirl.create(:vm_amazon)
      vm2 = FactoryGirl.create(:vm_amazon)

      child_stack = FactoryGirl.create(:orchestration_stack_amazon, :parent => deployed_stack)
      deployed_stack.direct_vms << vm1
      child_stack.direct_vms << vm2

      expect(service_with_deployed_stack.all_vms.map(&:id)).to match_array([vm1, vm2].map(&:id))
      expect(service_with_deployed_stack.direct_vms.map(&:id)).to match_array([vm1].map(&:id))
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

  context '#post_provision_configure' do
    it 'sets owners for all vms included in the stack' do
      vms = [FactoryGirl.create(:vm_amazon), FactoryGirl.create(:vm_amazon)]
      deployed_stack.direct_vms.push(*vms)

      service_with_deployed_stack.post_provision_configure
      vms.each do |vm|
        vm.reload
        expect(vm.evm_owner).to eq(service_with_deployed_stack.evm_owner)
        expect(vm.miq_group).to eq(service_with_deployed_stack.miq_group)
      end
    end
  end
end
