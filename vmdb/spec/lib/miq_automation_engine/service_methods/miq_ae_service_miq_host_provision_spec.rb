require "spec_helper"

module MiqAeServiceMiqHostProvisionSpec
  describe MiqAeMethodService::MiqAeServiceMiqHostProvision do
    before(:each) do
      MiqAutomateHelper.create_service_model_method('SPEC_DOMAIN', 'EVM',
                                                    'AUTOMATE', 'test1', 'test')
      @ae_method     = ::MiqAeMethod.find(:first)
      @ae_result_key = 'foo'

      @miq_host_provision = FactoryGirl.create(:miq_host_provision, :provision_type => 'host_pxe_install', :state => 'pending', :status => 'Ok')
    end

    def invoke_ae
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?MiqHostProvision::miq_host_provision=#{@miq_host_provision.id}")
    end

    it "#miq_host_provision_request" do
      user = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred')
      approver_role              = FactoryGirl.create(:ui_task_set_approver)
      miq_host_provision_request = FactoryGirl.create(:miq_host_provision_request, :provision_type => 'host_pxe_install', :state => 'pending', :status => 'Ok', :userid => user.userid)
      @miq_host_provision.miq_host_provision_request = miq_host_provision_request
      @miq_host_provision.save!

      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_host_provision'].miq_host_provision_request"
      @ae_method.update_attributes!(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      ae_object.should be_kind_of(MiqAeMethodService::MiqAeServiceMiqHostProvisionRequest)
      [:id, :provision_type, :state, :userid].each { |method| ae_object.send(method).should == miq_host_provision_request.send(method) }
    end

    it "#host" do
      host = FactoryGirl.create(:host)
      @miq_host_provision.host = host
      @miq_host_provision.save!
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_host_provision'].host"
      @ae_method.update_attributes!(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      ae_object.should be_kind_of(MiqAeMethodService::MiqAeServiceHost)
      [:id].each { |method| ae_object.send(method).should == host.send(method) }
    end

    context "#status" do
      before(:each) do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_host_provision'].status"
        @ae_method.update_attributes!(:data => method, :display_name => 'RSpec')
      end

      it "#status should return 'retry' unless state is finished or provisioned" do
        @miq_host_provision.update_attributes(:state => 'queued')
        invoke_ae.root(@ae_result_key).should == 'retry'
      end

      it "#status should return 'ok' when state is finished or provisioned and host has been rediscovered" do
        MiqHostProvision.any_instance.stub(:host_rediscovered?).and_return(true)
        ['finished', 'provisioned'].each do |state|
          @miq_host_provision.update_attributes(:state => state)
          invoke_ae.root(@ae_result_key).should == 'ok'
        end
      end

      it "#status should return 'error' when state is finished or provisioned and host has not been rediscovered" do
        MiqHostProvision.any_instance.stub(:host_rediscovered?).and_return(false)
        ['finished', 'provisioned'].each do |state|
          @miq_host_provision.update_attributes(:state => state)
          invoke_ae.root(@ae_result_key).should == 'error'
        end
      end
    end
  end
end
