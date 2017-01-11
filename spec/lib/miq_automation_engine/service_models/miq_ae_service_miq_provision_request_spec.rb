module MiqAeServiceMiqProvisionRequestSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceMiqProvisionRequest do
    def assert_ae_provision_matches_ar_provision(ae_object, ar_object)
      expect(ae_object).to be_kind_of(MiqAeMethodService::MiqAeServiceMiqProvision)
      [:id, :provision_type, :state, :options].each { |method| expect(ae_object.send(method)).to eq(ar_object.send(method)) }
    end

    before(:each) do
      Spec::Support::MiqAutomateHelper.create_service_model_method('SPEC_DOMAIN', 'EVM', 'AUTOMATE', 'test1', 'test')
      @ae_method     = ::MiqAeMethod.first
      @ae_result_key = 'foo'

      @ems                   = FactoryGirl.create(:ems_vmware_with_authentication)
      @vm_template           = FactoryGirl.create(:template_vmware, :ext_management_system => @ems)
      @user                  = FactoryGirl.create(:user_with_group)
      @miq_provision_request = FactoryGirl.create(:miq_provision_request, :provision_type => 'template', :state => 'pending', :status => 'Ok', :src_vm_id => @vm_template.id, :requester => @user)
    end

    def invoke_ae
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?MiqProvisionRequest::miq_provision_request=#{@miq_provision_request.id}", @user)
    end

    it "#miq_request" do
      @miq_provision_request.save!

      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision_request'].miq_request"
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      expect(ae_object).to be_kind_of(MiqAeMethodService::MiqAeServiceMiqRequest)
      expect(ae_object.id).to eq(@miq_provision_request.id)
    end

    it "#miq_provisions" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision_request'].miq_provisions"
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      expect(ae_object).to eq([])

      options       = {}
      options[:src_vm_id] = [@vm_template.id, @vm_template.name]
      options[:pass]      = 1
      miq_provision1 = FactoryGirl.create(:miq_provision, :provision_type => 'template', :state => 'pending', :status => 'Ok', :options => options)
      miq_provision2 = FactoryGirl.create(:miq_provision, :provision_type => 'template', :state => 'pending', :status => 'Ok', :options => options)

      @miq_provision_request.miq_provisions = [miq_provision1]
      @miq_provision_request.save!
      ae_object = invoke_ae.root(@ae_result_key)
      expect(ae_object).to be_kind_of(Array)
      expect(ae_object.length).to eq(1)
      assert_ae_provision_matches_ar_provision(ae_object.first, miq_provision1)

      @miq_provision_request.miq_provisions = [miq_provision1, miq_provision2]
      @miq_provision_request.save!
      ae_object = invoke_ae.root(@ae_result_key)
      expect(ae_object).to be_kind_of(Array)
      expect(ae_object.length).to eq(2)
      ae_object.each do |miq_ae_provision|
        expect([miq_provision1.id, miq_provision2.id]).to include(miq_ae_provision.id)
        ar_object =
          case miq_ae_provision.id
          when miq_provision1.id then miq_provision1
          when miq_provision2.id then miq_provision2
          end
        assert_ae_provision_matches_ar_provision(miq_ae_provision, ar_object)
      end
    end

    it "#vm_template" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision_request'].vm_template"
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      expect(ae_object).to be_kind_of(MiqAeMethodService::MiqAeServiceMiqTemplate)
      [:id, :name, :location].each { |method| expect(ae_object.send(method)).to eq(@vm_template.send(method)) }
    end

    it "#request_type" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision_request'].request_type"
      @ae_method.update_attributes(:data => method)

      %w( template clone_to_vm clone_to_template ).each do |provision_type|
        @miq_provision_request.update_attributes(:provision_type => provision_type)
        expect(invoke_ae.root(@ae_result_key)).to eq(@miq_provision_request.provision_type)
      end
    end

    it "#target_type" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision_request'].target_type"
      @ae_method.update_attributes(:data => method)

      %w( clone_to_template ).each do |provision_type|
        @miq_provision_request.update_attributes(:provision_type => provision_type)
        expect(invoke_ae.root(@ae_result_key)).to eq('template')
      end

      %w( template clone_to_vm ).each do |provision_type|
        @miq_provision_request.update_attributes(:provision_type => provision_type)
        expect(invoke_ae.root(@ae_result_key)).to eq('vm')
      end
    end

    it "#register_automate_callback - no previous callbacks" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision_request'].register_automate_callback(:first_time_out, 'do_something_great')"
      @ae_method.update_attributes(:data => method)
      expect(invoke_ae.root(@ae_result_key)).to be_truthy
      expect(@miq_provision_request[:options][:callbacks]).to be_nil
      @miq_provision_request.reload
      callback_hash = @miq_provision_request[:options][:callbacks]
      expect(callback_hash.count).to eq(1)
      expect(callback_hash[:first_time_out]).to eq('do_something_great')
    end

    it "#register_automate_callback - with previous callbacks" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision_request'].register_automate_callback(:first_time_out, 'do_something_great')"
      @ae_method.update_attributes(:data => method)
      expect(@miq_provision_request[:options][:callbacks]).to be_nil
      opts = @miq_provision_request.options.dup
      opts[:callbacks] = {:next_time_around => 'do_something_better_yet'}
      @miq_provision_request.update_attributes(:options => opts)
      expect(invoke_ae.root(@ae_result_key)).to be_truthy
      @miq_provision_request.reload
      callback_hash = @miq_provision_request[:options][:callbacks]
      expect(callback_hash.count).to eq(2)
      expect(callback_hash[:first_time_out]).to eq('do_something_great')
      expect(callback_hash[:next_time_around]).to eq('do_something_better_yet')
    end

    it "#source_type" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision_request'].source_type"
      @ae_method.update_attributes(:data => method)

      vm = VmOrTemplate.find(@vm_template.id)
      vm.template = true
      vm.save!
      expect(invoke_ae.root(@ae_result_key)).to eq('template')

      vm = VmOrTemplate.find(@vm_template.id)
      vm.template = false
      vm.save!
      expect(invoke_ae.root(@ae_result_key)).to eq('vm')
    end

    it "#ci_type" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision_request'].ci_type"
      @ae_method.update_attributes(:data => method)
      expect(invoke_ae.root(@ae_result_key)).to eq('vm')
    end
  end
end
