require "spec_helper"

module MiqAeServiceServiceTemplateProvisionRequestSpec
  describe MiqAeMethodService::MiqAeServiceServiceTemplateProvisionRequest do
    before(:each) do
      MiqAutomateHelper.create_service_model_method('SPEC_DOMAIN', 'EVM',
                                                    'AUTOMATE', 'test1', 'test')
      @ae_method     = ::MiqAeMethod.find(:first)
      @ae_result_key = 'foo'
      @user          = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred')
      @approver_role = FactoryGirl.create(:ui_task_set_approver)
      @service_template_provision_request = FactoryGirl.create(:service_template_provision_request,  :requester => @user, :userid => @user.userid)
    end

    def invoke_ae
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?ServiceTemplateProvisionRequest::service_template_provision_request=#{@service_template_provision_request.id}")
    end

    it "#approve" do
      approver = 'wilma'
      reason   = "Why Not?"
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['service_template_provision_request'].approve('#{approver}', '#{reason}')"
      @ae_method.update_attributes(:data => method)
      MiqRequest.any_instance.should_receive(:approve).with(approver, reason).once
      invoke_ae.root(@ae_result_key).should  be_true
    end
  end
end
