module MiqAeServiceMiqHostProvisionSpec
  describe MiqAeMethodService::MiqAeServiceMiqHostProvision do
    before(:each) do
      @user = FactoryGirl.create(:user_with_group)
      Spec::Support::MiqAutomateHelper.create_service_model_method('SPEC_DOMAIN', 'EVM', 'AUTOMATE', 'test1', 'test')
      @ae_method     = ::MiqAeMethod.first
      @ae_result_key = 'foo'

      @miq_host_provision = FactoryGirl.create(:miq_host_provision, :provision_type => 'host_pxe_install', :state => 'pending', :status => 'Ok')
    end

    def invoke_ae
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?MiqHostProvision::miq_host_provision=#{@miq_host_provision.id}", @user)
    end

    it "#miq_host_provision_request" do
      miq_host_provision_request = FactoryGirl.create(:miq_host_provision_request, :provision_type => 'host_pxe_install', :state => 'pending', :status => 'Ok', :requester => @user)
      @miq_host_provision.miq_host_provision_request = miq_host_provision_request
      @miq_host_provision.save!

      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_host_provision'].miq_host_provision_request"
      @ae_method.update_attributes!(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      expect(ae_object).to be_kind_of(MiqAeMethodService::MiqAeServiceMiqHostProvisionRequest)
      [:id, :provision_type, :state, :userid].each { |method| expect(ae_object.send(method)).to eq(miq_host_provision_request.send(method)) }
    end

    it "#host" do
      host = FactoryGirl.create(:host)
      @miq_host_provision.host = host
      @miq_host_provision.save!
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_host_provision'].host"
      @ae_method.update_attributes!(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      expect(ae_object).to be_kind_of(MiqAeMethodService::MiqAeServiceHost)
      [:id].each { |method| expect(ae_object.send(method)).to eq(host.send(method)) }
    end

    context "#status" do
      before(:each) do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_host_provision'].status"
        @ae_method.update_attributes!(:data => method, :display_name => 'RSpec')
      end

      it "#status should return 'retry' unless state is finished or provisioned" do
        @miq_host_provision.update_attributes(:state => 'queued')
        expect(invoke_ae.root(@ae_result_key)).to eq('retry')
      end

      it "#status should return 'ok' when state is finished or provisioned and host has been rediscovered" do
        allow_any_instance_of(MiqHostProvision).to receive(:host_rediscovered?).and_return(true)
        ['finished', 'provisioned'].each do |state|
          @miq_host_provision.update_attributes(:state => state)
          expect(invoke_ae.root(@ae_result_key)).to eq('ok')
        end
      end

      it "#status should return 'error' when state is finished or provisioned and host has not been rediscovered" do
        allow_any_instance_of(MiqHostProvision).to receive(:host_rediscovered?).and_return(false)
        ['finished', 'provisioned'].each do |state|
          @miq_host_provision.update_attributes(:state => state)
          expect(invoke_ae.root(@ae_result_key)).to eq('error')
        end
      end
    end
  end
end
