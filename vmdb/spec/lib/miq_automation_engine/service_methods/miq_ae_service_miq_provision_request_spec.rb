require "spec_helper"

module MiqAeServiceMiqProvisionRequestSpec
  include MiqAeEngine
  describe MiqAeMethodService::MiqAeServiceMiqProvisionRequest do
    def assert_ae_provision_matches_ar_provision(ae_object, ar_object)
      ae_object.should be_kind_of(MiqAeMethodService::MiqAeServiceMiqProvision)
      [:id, :provision_type, :state, :options].each { |method| ae_object.send(method).should == ar_object.send(method) }
    end

    before(:each) do
      MiqAutomateHelper.create_service_model_method('SPEC_DOMAIN', 'EVM',
                                                    'AUTOMATE', 'test1', 'test')
      @ae_method     = ::MiqAeMethod.find(:first)
      @ae_result_key = 'foo'

      @ems                   = FactoryGirl.create(:ems_vmware_with_authentication)
      @vm_template           = FactoryGirl.create(:template_vmware, :ext_management_system => @ems)
      @user                  = FactoryGirl.create(:user, :name => 'Fred Flintstone',  :userid => 'fred')
      approver_role          = FactoryGirl.create(:ui_task_set_approver)
      @miq_provision_request = FactoryGirl.create(:miq_provision_request, :provision_type => 'template', :state => 'pending', :status => 'Ok', :src_vm_id => @vm_template.id, :userid => @user.userid)
    end

    def invoke_ae
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?MiqProvisionRequest::miq_provision_request=#{@miq_provision_request.id}")
    end

    it "#miq_request" do
      miq_request = @miq_provision_request.create_request
      @miq_provision_request.save!

      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision_request'].miq_request"
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      ae_object.should be_kind_of(MiqAeMethodService::MiqAeServiceMiqRequest)
      [:id].each { |method| ae_object.send(method).should == miq_request.send(method) }
    end

    it "#miq_provisions" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision_request'].miq_provisions"
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      ae_object.should == []

      options       = {}
      options[:src_vm_id] = [@vm_template.id, @vm_template.name]
      options[:pass]      = 1
      miq_provision1 = FactoryGirl.create(:miq_provision, :provision_type => 'template', :state => 'pending', :status => 'Ok', :options => options)
      miq_provision2 = FactoryGirl.create(:miq_provision, :provision_type => 'template', :state => 'pending', :status => 'Ok', :options => options)

      @miq_provision_request.miq_provisions = [miq_provision1]
      @miq_provision_request.save!
      ae_object = invoke_ae.root(@ae_result_key)
      ae_object.should be_kind_of(Array)
      ae_object.length.should == 1
      assert_ae_provision_matches_ar_provision(ae_object.first, miq_provision1)

      @miq_provision_request.miq_provisions = [miq_provision1, miq_provision2]
      @miq_provision_request.save!
      ae_object = invoke_ae.root(@ae_result_key)
      ae_object.should be_kind_of(Array)
      ae_object.length.should == 2
      ae_object.each do |miq_ae_provision|
        [miq_provision1.id, miq_provision2.id].should include(miq_ae_provision.id)
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
      ae_object.should be_kind_of(MiqAeMethodService::MiqAeServiceMiqTemplate)
      [:id, :name, :location].each { |method| ae_object.send(method).should == @vm_template.send(method) }
    end

    it "#request_type" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision_request'].request_type"
      @ae_method.update_attributes(:data => method)

      %w{ template clone_to_vm clone_to_template }.each do |provision_type|
        @miq_provision_request.update_attributes(:provision_type => provision_type)
        invoke_ae.root(@ae_result_key).should == @miq_provision_request.provision_type
      end
    end

    it "#target_type" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision_request'].target_type"
      @ae_method.update_attributes(:data => method)

      %w{ clone_to_template }.each do |provision_type|
        @miq_provision_request.update_attributes(:provision_type => provision_type)
        invoke_ae.root(@ae_result_key).should == 'template'
      end

      %w{ template clone_to_vm }.each do |provision_type|
        @miq_provision_request.update_attributes(:provision_type => provision_type)
        invoke_ae.root(@ae_result_key).should == 'vm'
      end
    end

    it "#register_automate_callback - no previous callbacks" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision_request'].register_automate_callback(:first_time_out, 'do_something_great')"
      @ae_method.update_attributes(:data => method)
      invoke_ae.root(@ae_result_key).should be_true
      @miq_provision_request[:options][:callbacks].should be_nil
      @miq_provision_request.reload
      callback_hash = @miq_provision_request[:options][:callbacks]
      callback_hash.count.should  == 1
      callback_hash[:first_time_out].should == 'do_something_great'
    end

    it "#register_automate_callback - with previous callbacks" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision_request'].register_automate_callback(:first_time_out, 'do_something_great')"
      @ae_method.update_attributes(:data => method)
      @miq_provision_request[:options][:callbacks].should be_nil
      opts = @miq_provision_request.options.dup
      opts[:callbacks] = {:next_time_around => 'do_something_better_yet'}
      @miq_provision_request.update_attributes(:options => opts)
      invoke_ae.root(@ae_result_key).should be_true
      @miq_provision_request.reload
      callback_hash = @miq_provision_request[:options][:callbacks]
      callback_hash.count.should  == 2
      callback_hash[:first_time_out].should == 'do_something_great'
      callback_hash[:next_time_around].should == 'do_something_better_yet'
    end

    it "#source_type" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision_request'].source_type"
      @ae_method.update_attributes(:data => method)

      vm = VmOrTemplate.find(@vm_template.id)
      vm.template = true
      vm.save!
      invoke_ae.root(@ae_result_key).should == 'template'

      vm = VmOrTemplate.find(@vm_template.id)
      vm.template = false
      vm.save!
      invoke_ae.root(@ae_result_key).should == 'vm'
    end

    it "#ci_type" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision_request'].ci_type"
      @ae_method.update_attributes(:data => method)
      invoke_ae.root(@ae_result_key).should == 'vm'
    end
  end
end
