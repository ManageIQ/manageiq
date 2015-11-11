require "spec_helper"

module MiqAeServiceServiceTemplateProvisionRequestSpec
  describe MiqAeMethodService::MiqAeServiceServiceTemplateProvisionRequest do
    let(:service_service_template_provision_request) do
      MiqAeMethodService::MiqAeServiceServiceTemplateProvisionRequest.find(@service_template_provision_request.id)
    end

    before(:each) do
      MiqAutomateHelper.create_service_model_method('SPEC_DOMAIN', 'EVM',
                                                    'AUTOMATE', 'test1', 'test')
      @ae_method     = ::MiqAeMethod.first
      @ae_result_key = 'foo'
      @user          = FactoryGirl.create(:user_with_group, :name => 'Fred Flintstone',  :userid => 'fred')
      @service_template_provision_request = FactoryGirl.create(:service_template_provision_request, :requester => @user)
    end

    def invoke_ae
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?ServiceTemplateProvisionRequest::service_template_provision_request=#{@service_template_provision_request.id}", @user)
    end

    it "#approve" do
      approver = 'wilma'
      reason   = "Why Not?"
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['service_template_provision_request'].approve('#{approver}', '#{reason}')"
      @ae_method.update_attributes(:data => method)
      MiqRequest.any_instance.should_receive(:approve).with(approver, reason).once
      invoke_ae.root(@ae_result_key).should be_true
    end

    it "#user_message" do
      service_service_template_provision_request.user_message = "fred"

      expect(@service_template_provision_request.reload.message).to eq("fred")
      expect(@service_template_provision_request.reload.options[:user_message]).to eq("fred")
    end

    it "#user_message reset" do
      service_service_template_provision_request.user_message = "fred"
      expect(@service_template_provision_request.reload.message).to eq("fred")
      expect(@service_template_provision_request.reload.options[:user_message]).to eq("fred")

      service_service_template_provision_request.user_message = ""
      expect(@service_template_provision_request.reload.message).to eq("fred")
      expect(@service_template_provision_request.reload.options[:user_message]).to be_blank
    end
  end
end
