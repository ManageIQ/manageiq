require "spec_helper"

module MiqAeServiceMiqHostProvisionRequestSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceMiqHostProvisionRequest do
    def assert_ae_host_provision_matches_ar_host_provision(ae_object, ar_object)
      ae_object.should be_kind_of(MiqAeMethodService::MiqAeServiceMiqHostProvision)
      [:id, :provision_type, :state, :options].each { |method| ae_object.send(method).should == ar_object.send(method) }
    end

    before(:each) do
      MiqAutomateHelper.create_service_model_method('SPEC_DOMAIN', 'EVM',
                                                    'AUTOMATE', 'test1', 'test')
      @ae_method     = ::MiqAeMethod.find(:first)
      @ae_result_key = 'foo'

      @user                       = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred')
      approver_role               = FactoryGirl.create(:ui_task_set_approver)
      @miq_host_provision_request = FactoryGirl.create(:miq_host_provision_request, :provision_type => 'host_pxe_install', :state => 'pending', :status => 'Ok', :userid => @user.userid)
    end

    def invoke_ae
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?MiqHostProvisionRequest::miq_host_provision_request=#{@miq_host_provision_request.id}")
    end

    it "#miq_request" do
      miq_request = @miq_host_provision_request.create_request
      @miq_host_provision_request.save!

      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_host_provision_request'].miq_request"
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      ae_object.should be_kind_of(MiqAeMethodService::MiqAeServiceMiqRequest)
      [:id].each { |method| ae_object.send(method).should == miq_request.send(method) }
    end

    it "#miq_host_provisions" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_host_provision_request'].miq_host_provisions"
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      ae_object.should == []

      miq_host_provision1 = FactoryGirl.create(:miq_host_provision, :provision_type => 'host_pxe_install', :state => 'pending', :status => 'Ok')
      miq_host_provision2 = FactoryGirl.create(:miq_host_provision, :provision_type => 'host_pxe_install', :state => 'pending', :status => 'Ok')

      @miq_host_provision_request.miq_host_provisions = [miq_host_provision1]
      @miq_host_provision_request.save!
      ae_object = invoke_ae.root(@ae_result_key)
      ae_object.should be_kind_of(Array)
      ae_object.length.should == 1
      assert_ae_host_provision_matches_ar_host_provision(ae_object.first, miq_host_provision1)

      @miq_host_provision_request.miq_host_provisions = [miq_host_provision1, miq_host_provision2]
      @miq_host_provision_request.save!
      ae_object = invoke_ae.root(@ae_result_key)
      ae_object.should be_kind_of(Array)
      ae_object.length.should == 2
      ae_object.each do |miq_ae_host_provision|
        [miq_host_provision1.id, miq_host_provision2.id].should include(miq_ae_host_provision.id)
        ar_object =
          case miq_ae_host_provision.id
          when miq_host_provision1.id then miq_host_provision1
          when miq_host_provision2.id then miq_host_provision2
          end
        assert_ae_host_provision_matches_ar_host_provision(miq_ae_host_provision, ar_object)
      end
    end

    it "#ci_type" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_host_provision_request'].ci_type"
      @ae_method.update_attributes(:data => method)
      invoke_ae.root(@ae_result_key).should == 'host'
    end

    pending "Not yet implemented: 10 specs" do
      it "#options"
      it "#get_option"
      it "#set_option"
      it "#set_message"
      it "#get_tag"
      it "#get_tags"
      it "#clear_tag"
      it "#add_tag"
      it "#get_classification"
      it "#get_classifications"
    end
  end
end
