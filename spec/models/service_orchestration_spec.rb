require "spec_helper"

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

  let(:service) { FactoryGirl.create(:service_orchestration) }

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
      service_with_dialog_options.stack_name.should == 'test123'
    end

    it "gets stack name from overridden value" do
      service_with_dialog_options.stack_name = "new_name"
      service_with_dialog_options.stack_name.should == "new_name"
    end
  end

  context "#stack_options" do
    before do
      allow_any_instance_of(ManageIQ::Providers::Amazon::CloudManager::OrchestrationServiceOptionConverter).to(
        receive(:stack_create_options).and_return(dialog_options))
    end

    it "gets stack options set by dialog" do
      service_with_dialog_options.stack_options.should == dialog_options
    end

    it "gets stack options from overridden values" do
      new_options = {"any_key" => "any_value"}
      service_with_dialog_options.stack_options = new_options
      service_with_dialog_options.stack_options.should == new_options
    end

    it "encrypts password when saves to DB" do
      new_options = {:parameters => {"my_password" => "secret"}}
      service_with_dialog_options.stack_options = new_options
      service_with_dialog_options.options[:create_options][:parameters]["my_password"].should == MiqPassword.encrypt("secret")
    end

    it "prefers the orchestration template set by dialog" do
      service_mix_dialog_setter.orchestration_template.should == template_by_setter
      service_mix_dialog_setter.stack_options
      service_mix_dialog_setter.orchestration_template.should == template_by_dialog
    end

    it "prefers the orchestration manager set by dialog" do
      service_mix_dialog_setter.orchestration_manager.should == manager_by_setter
      service_mix_dialog_setter.stack_options
      service_mix_dialog_setter.orchestration_manager.should == manager_by_dialog
    end
  end

  context '#deploy_orchestration_stack' do
    it 'creates a stack through cloud manager' do
      ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack.stub(:raw_create_stack) do |manager, name, template, opts|
        manager.should == manager_by_setter
        name.should == 'test123'
        template.should be_kind_of OrchestrationTemplate
        opts.should be_kind_of Hash
      end

      service_mix_dialog_setter.deploy_orchestration_stack
    end

    it 'always saves options even when the manager fails to create a stack' do
      ProvisionError = MiqException::MiqOrchestrationProvisionError
      ManageIQ::Providers::Amazon::CloudManager.any_instance.stub(:stack_create).and_raise(ProvisionError, 'test failure')

      service_mix_dialog_setter.should_receive(:save_create_options)
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
      OrchestrationStack.any_instance.stub(:raw_update_stack) do |new_template, opts|
        opts[:parameters].should include(
          'InstanceType'   => 'cg1.4xlarge',
          'DBRootPassword' => 'admin'
        )
        new_template.should == template_by_setter
      end
      reconfigurable_service.update_orchestration_stack
    end

    it 'saves update options and encrypts password' do
      reconfigurable_service.options[:update_options][:parameters]['DBRootPassword'].should == MiqPassword.encrypt("admin")
    end
  end

  context '#orchestration_stack_status' do
    it 'returns an error if stack has never been deployed' do
      status, _message = service_mix_dialog_setter.orchestration_stack_status
      status.should == 'check_status_failed'
    end

    it 'returns current stack status through provider' do
      status_obj = ManageIQ::Providers::Amazon::CloudManager::OrchestrationStack::Status.new('CREATE_COMPLETE', 'no error')
      deployed_stack.stub(:raw_status).and_return(status_obj)

      status, message = service_with_deployed_stack.orchestration_stack_status
      status.should == 'create_complete'
      message.should == 'no error'
    end

    it 'returns an error message when the provider fails to retrieve the status' do
      deployed_stack.stub(:raw_status).and_raise(MiqException::MiqOrchestrationStatusError, 'test failure')

      status, message = service_with_deployed_stack.orchestration_stack_status
      status.should == 'check_status_failed'
      message.should == 'test failure'
    end
  end

  context '#all_vms' do
    it 'returns all vms from a deployed stack' do
      vm1 = double
      vm2 = double
      allow(deployed_stack).to receive(:vms).and_return([vm1, vm2])
      allow(deployed_stack).to receive(:direct_vms).and_return([vm1])

      expect(service_with_deployed_stack.all_vms).to eq([vm1, vm2])
      expect(service_with_deployed_stack.direct_vms).to eq([vm1])
      expect(service_with_deployed_stack.indirect_vms).to eq([vm2])
      expect(service_with_deployed_stack.vms).to eq([vm1, vm2])
    end

    it 'returns no vm if no stack is deployed' do
      expect(service.all_vms).to be_empty
      expect(service.direct_vms).to be_empty
      expect(service.indirect_vms).to be_empty
      expect(service.vms).to be_empty
    end
  end
end
