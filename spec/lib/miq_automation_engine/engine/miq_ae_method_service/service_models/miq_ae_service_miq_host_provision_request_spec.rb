module MiqAeServiceMiqHostProvisionRequestSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceMiqHostProvisionRequest do
    def assert_ae_host_provision_matches_ar_host_provision(ae_object, ar_object)
      expect(ae_object).to be_kind_of(MiqAeMethodService::MiqAeServiceMiqHostProvision)
      [:id, :provision_type, :state, :options].each { |method| expect(ae_object.send(method)).to eq(ar_object.send(method)) }
    end

    before(:each) do
      Spec::Support::MiqAutomateHelper.create_service_model_method('SPEC_DOMAIN', 'EVM', 'AUTOMATE', 'test1', 'test')
      @ae_method     = ::MiqAeMethod.first
      @ae_result_key = 'foo'

      @user                       = FactoryGirl.create(:user_with_group)
      @miq_host_provision_request = FactoryGirl.create(:miq_host_provision_request, :provision_type => 'host_pxe_install', :state => 'pending', :status => 'Ok', :requester => @user)
    end

    def invoke_ae
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?MiqHostProvisionRequest::miq_host_provision_request=#{@miq_host_provision_request.id}", @user)
    end

    it "#miq_request" do
      @miq_host_provision_request.save!

      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_host_provision_request'].miq_request"
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      expect(ae_object).to be_kind_of(MiqAeMethodService::MiqAeServiceMiqRequest)
      expect(ae_object.id).to eq(@miq_host_provision_request.id)
    end

    it "#miq_host_provisions" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_host_provision_request'].miq_host_provisions"
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      expect(ae_object).to eq([])

      miq_host_provision1 = FactoryGirl.create(:miq_host_provision, :provision_type => 'host_pxe_install', :state => 'pending', :status => 'Ok')
      miq_host_provision2 = FactoryGirl.create(:miq_host_provision, :provision_type => 'host_pxe_install', :state => 'pending', :status => 'Ok')

      @miq_host_provision_request.miq_host_provisions = [miq_host_provision1]
      @miq_host_provision_request.save!
      ae_object = invoke_ae.root(@ae_result_key)
      expect(ae_object).to be_kind_of(Array)
      expect(ae_object.length).to eq(1)
      assert_ae_host_provision_matches_ar_host_provision(ae_object.first, miq_host_provision1)

      @miq_host_provision_request.miq_host_provisions = [miq_host_provision1, miq_host_provision2]
      @miq_host_provision_request.save!
      ae_object = invoke_ae.root(@ae_result_key)
      expect(ae_object).to be_kind_of(Array)
      expect(ae_object.length).to eq(2)
      ae_object.each do |miq_ae_host_provision|
        expect([miq_host_provision1.id, miq_host_provision2.id]).to include(miq_ae_host_provision.id)
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
      expect(invoke_ae.root(@ae_result_key)).to eq('host')
    end
  end
end
