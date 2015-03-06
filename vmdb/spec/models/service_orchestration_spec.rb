require "spec_helper"

describe ServiceTemplate do
  let(:manager_by_setter)  { FactoryGirl.create(:ems_amazon) }
  let(:template_by_setter) { FactoryGirl.create(:orchestration_template) }
  let(:manager_by_dialog)  { FactoryGirl.create(:ems_amazon) }
  let(:template_by_dialog) { FactoryGirl.create(:orchestration_template) }

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
      allow_any_instance_of(ServiceOrchestration::OptionConverterAmazon).to(
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
      EmsAmazon.any_instance.stub(:stack_create) do |name, template, opts|
        name.should == 'test123'
        template.should be_kind_of OrchestrationTemplate
        opts.should be_kind_of Hash
      end

      service_mix_dialog_setter.deploy_orchestration_stack
    end

    it 'always saves options even when the manager fails to create a stack' do
      ProvisionError = MiqException::MiqOrchestrationProvisionError
      EmsAmazon.any_instance.stub(:stack_create).and_raise(ProvisionError, 'test failure')

      service_mix_dialog_setter.should_receive(:save_options)
      expect { service_mix_dialog_setter.deploy_orchestration_stack }.to raise_error(ProvisionError)
    end
  end

  context '#orchestration_stack_status' do
    it 'returns an error if stack has never been deployed' do
      status, _message = service_mix_dialog_setter.orchestration_stack_status
      status.should  == 'check_status_failed'
    end

    it 'returns current stack status through provider' do
      EmsAmazon.any_instance.stub(:stack_status).and_return(['create_complete', 'no error'])

      service_mix_dialog_setter.options[:stack_ems_ref] = 'abc'  # simulate stack deployed
      status, message = service_mix_dialog_setter.orchestration_stack_status

      status.should  == 'create_complete'
      message.should == 'no error'
    end

    it 'returns an error message when the provider fails to retrieve the status' do
      EmsAmazon.any_instance.stub(:stack_status)
        .and_raise(MiqException::MiqOrchestrationStatusError, 'test failure')

      service_mix_dialog_setter.options[:stack_ems_ref] = 'abc'  # simulate stack deployed
      status, message = service_mix_dialog_setter.orchestration_stack_status
      status.should  == 'check_status_failed'
      message.should == 'test failure'
    end
  end

end
