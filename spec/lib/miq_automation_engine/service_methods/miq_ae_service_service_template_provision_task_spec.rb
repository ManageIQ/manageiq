module MiqAeServiceServiceTemplateProvisionTaskSpec
  describe MiqAeMethodService::MiqAeServiceServiceTemplateProvisionTask do
    let(:service_service_template_provision_task) do
      MiqAeMethodService::MiqAeServiceServiceTemplateProvisionTask.find(@service_template_provision_task.id)
    end

    before(:each) do
      Spec::Support::MiqAutomateHelper.create_service_model_method('SPEC_DOMAIN', 'EVM', 'AUTOMATE', 'test1', 'test')
      @ae_method     = ::MiqAeMethod.first
      @user          = FactoryGirl.create(:user_with_group)
      @ae_result_key = 'foo'
      @options       = {}
      @service_template_provision_task = FactoryGirl.create(:service_template_provision_task, :options => @options)
    end

    def invoke_ae
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?ServiceTemplateProvisionTask::service_template_provision_task=#{@service_template_provision_task.id}", @user)
    end

    it "#execute" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['service_template_provision_task'].execute"
      @ae_method.update_attributes(:data => method)
      expect_any_instance_of(ServiceTemplateProvisionTask).to receive(:execute_queue).once
      expect(invoke_ae.root(@ae_result_key)).to be_truthy
    end

    it "#user_message" do
      service_service_template_provision_task.user_message = "fred"

      expect(@service_template_provision_task.reload.message).to eq("fred")
      expect(@service_template_provision_task.reload.options[:user_message]).to eq("fred")
    end

    it "#user_message reset" do
      service_service_template_provision_task.user_message = "fred"
      expect(@service_template_provision_task.reload.message).to eq("fred")
      expect(@service_template_provision_task.reload.options[:user_message]).to eq("fred")

      service_service_template_provision_task.user_message = ""
      expect(@service_template_provision_task.reload.message).to eq("fred")
      expect(@service_template_provision_task.reload.options[:user_message]).to be_blank
    end

    context "#status" do
      it "when state is provisioned" do
        @service_template_provision_task.update_attributes(:state => "provisioned")
        method   = "$evm.root['#{@ae_result_key}'] = $evm.root['service_template_provision_task'].status"
        @ae_method.update_attributes!(:data => method)

        expect(invoke_ae.root(@ae_result_key)).to eq('ok')
      end

      it "when state is finished" do
        @service_template_provision_task.update_attributes(:state => "finished")
        method   = "$evm.root['#{@ae_result_key}'] = $evm.root['service_template_provision_task'].status"
        @ae_method.update_attributes!(:data => method)

        expect(invoke_ae.root(@ae_result_key)).to eq('ok')
      end

      it "when state is pending" do
        @service_template_provision_task.update_attributes(:state => "pending")
        method   = "$evm.root['#{@ae_result_key}'] = $evm.root['service_template_provision_task'].status"
        @ae_method.update_attributes!(:data => method)

        expect(invoke_ae.root(@ae_result_key)).to eq('retry')
      end
    end
  end
end
