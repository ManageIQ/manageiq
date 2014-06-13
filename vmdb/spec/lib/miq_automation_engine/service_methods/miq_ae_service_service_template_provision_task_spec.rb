require "spec_helper"

module MiqAeServiceServiceTemplateProvisionTaskSpec
  describe MiqAeMethodService::MiqAeServiceServiceTemplateProvisionTask do
    before(:each) do
      MiqAutomateHelper.create_service_model_method('SPEC_DOMAIN', 'EVM',
                                                    'AUTOMATE', 'test1', 'test')
      @ae_method     = ::MiqAeMethod.find(:first)
      @ae_result_key = 'foo'
      @options       = {}
      @service_template_provision_task = FactoryGirl.create(:service_template_provision_task,  :state => 'pending', :status => 'Ok', :request_type => "clone_to_service", :options => @options)
    end

    def invoke_ae
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?ServiceTemplateProvisionTask::service_template_provision_task=#{@service_template_provision_task.id}")
    end

    it "#execute" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['service_template_provision_task'].execute"
      @ae_method.update_attributes(:data => method)
      ServiceTemplateProvisionTask.any_instance.should_receive(:execute_queue).once
      invoke_ae.root(@ae_result_key).should be_true
    end

    context "#status" do
      it "when state is provisioned" do
        @service_template_provision_task.update_attributes(:state => "provisioned")
        method   = "$evm.root['#{@ae_result_key}'] = $evm.root['service_template_provision_task'].status"
        @ae_method.update_attributes!(:data => method)

        invoke_ae.root(@ae_result_key).should == 'ok'
      end

      it "when state is finished" do
        @service_template_provision_task.update_attributes(:state => "finished")
        method   = "$evm.root['#{@ae_result_key}'] = $evm.root['service_template_provision_task'].status"
        @ae_method.update_attributes!(:data => method)

        invoke_ae.root(@ae_result_key).should == 'ok'
      end

      it "when state is pending" do
        @service_template_provision_task.update_attributes(:state => "pending")
        method   = "$evm.root['#{@ae_result_key}'] = $evm.root['service_template_provision_task'].status"
        @ae_method.update_attributes!(:data => method)

        invoke_ae.root(@ae_result_key).should == 'retry'
      end
    end

  end
end
