require "spec_helper"

module MiqAeServiceServiceSpec
  describe MiqAeMethodService::MiqAeServiceService do
    before(:each) do
      MiqAutomateHelper.create_service_model_method('SPEC_DOMAIN', 'EVM',
                                                    'AUTOMATE', 'test1', 'test')
      @ae_method     = ::MiqAeMethod.find(:first)
      @ae_result_key = 'foo'

      @service   = FactoryGirl.create(:service, :name => "test_service", :description => "test_description")
    end

    def invoke_ae
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?Service::service=#{@service.id}")
    end

    it "#remove_from_vmdb" do
      Service.count.should == 1
      method = "$evm.root['#{@ae_result_key}'] = $evm.root['service'].remove_from_vmdb"
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      Service.count.should == 0
    end

    it "#set the service name" do
      @service.name.should == 'test_service'
      method = "$evm.root['#{@ae_result_key}'] = $evm.root['service'].name = 'new_test_service' "
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      @service.reload
      @service.name.should == 'new_test_service'
    end

    it "#set the service description" do
      @service.description.should == 'test_description'
      method = "$evm.root['#{@ae_result_key}'] = $evm.root['service'].description = 'new_test_description' "
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      @service.reload
      @service.description.should == 'new_test_description'
    end

    pending "Not yet implemented: specs" do
      it "#retires_on="
      it "#retirement_warn="
    end
  end
end
