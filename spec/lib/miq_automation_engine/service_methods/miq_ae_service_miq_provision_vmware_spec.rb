require 'spec_helper'

module MiqAeServiceManageIQ_Providers_Vmware_InfraManager_ProvisionSpec
  describe MiqAeMethodService::MiqAeServiceManageIQ_Providers_Vmware_InfraManager_Provision do
    before(:each) do
      MiqAutomateHelper.create_service_model_method('SPEC_DOMAIN', 'EVM',
                                                    'AUTOMATE', 'test1', 'test')
      @ae_method     = ::MiqAeMethod.first
      @ae_result_key = 'foo'

      @ems           = FactoryGirl.create(:ems_vmware_with_authentication)
      @vm_template   = FactoryGirl.create(:template_vmware, :ext_management_system => @ems)
      @options       = {}
      @options[:src_vm_id] = [@vm_template.id, @vm_template.name]
      @options[:pass]      = 1
      @user        = FactoryGirl.create(:user, :name => 'Fred Flintstone', :userid => 'fred')
      @miq_provision = FactoryGirl.create(:miq_provision_vmware,
                                          :provision_type => 'template',
                                          :state => 'pending', :status => 'Ok',
                                          :options => @options,
                                          :userid => @user.userid)
    end

    let(:ae_svc_prov) { MiqAeMethodService::MiqAeServiceMiqProvision.find(@miq_provision.id) }

    def invoke_ae
      target_key   = MiqAeEngine.create_automation_attribute_key(@miq_provision)
      target_value = MiqAeEngine.create_automation_attribute_value(@miq_provision)
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?#{target_key}=#{target_value}")
    end

    context "check requests" do
      before(:each) do
        FactoryGirl.create(:ui_task_set_approver)
        @miq_provision_request = FactoryGirl.create(:miq_provision_request,
                                                    :provision_type => 'template',
                                                    :state => 'pending', :status => 'Ok',
                                                    :src_vm_id => @vm_template.id,
                                                    :userid => @user.userid)
        @miq_provision.miq_provision_request = @miq_provision_request
        @miq_provision.save!
        @miq_provision_request.save!
      end

      it "#miq_request" do
        miq_request = @miq_provision_request.create_request
        method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision'].miq_request"
        @ae_method.update_attributes(:data => method)
        ae_object = invoke_ae.root(@ae_result_key)
        ae_object.should be_kind_of(MiqAeMethodService::MiqAeServiceMiqRequest)
        [:id].each { |meth| ae_object.send(meth).should == miq_request.send(meth) }
      end

      it "#miq_provision_request" do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision'].miq_provision_request"
        @ae_method.update_attributes(:data => method)
        ae_object = invoke_ae.root(@ae_result_key)
        ae_object.should be_kind_of(MiqAeMethodService::MiqAeServiceMiqProvisionRequest)
        [:id, :provision_type, :state, :status, :src_vm_id, :userid].each do |meth|
          ae_object.send(meth).should == @miq_provision_request.send(meth)
        end
      end
    end

    it "#vm" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision'].vm"
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      ae_object.should be_nil

      vm = FactoryGirl.create(:vm_vmware, :name => "vm42", :location => "vm42/vm42.vmx")
      @miq_provision.vm = vm
      @miq_provision.save!

      ae_object = invoke_ae.root(@ae_result_key)
      ae_object.should be_kind_of(MiqAeMethodService::MiqAeServiceVm)
      [:id, :name, :location].each { |meth| ae_object.send(meth).should == vm.send(meth) }

    end

    it "#vm_template" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision'].vm_template"
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      ae_object.should be_kind_of(MiqAeMethodService::MiqAeServiceMiqTemplate)
      [:id, :name, :location].each { |meth| ae_object.send(meth).should == @vm_template.send(meth) }
    end

    it "#execute" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision'].execute"
      @ae_method.update_attributes(:data => method)

      MiqProvision.any_instance.should_receive(:execute_queue).once
      invoke_ae.root(@ae_result_key).should be_true
    end

    it "#request_type" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision'].request_type"
      @ae_method.update_attributes(:data => method)

      %w{ template clone_to_vm clone_to_template }.each do |provision_type|
        @miq_provision.update_attributes(:provision_type => provision_type)
        invoke_ae.root(@ae_result_key).should == @miq_provision.provision_type
      end
    end

    it "#register_automate_callback - no previous callbacks" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision']"
      method  += ".register_automate_callback(:first_time_out, 'do_something_great')"
      @ae_method.update_attributes(:data => method)
      invoke_ae.root(@ae_result_key).should be_true
      @miq_provision[:options][:callbacks].should be_nil
      @miq_provision.reload
      callback_hash = @miq_provision[:options][:callbacks]
      callback_hash.count.should eq(1)
      callback_hash[:first_time_out].should == 'do_something_great'
    end

    it "#register_automate_callback - with previous callbacks" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision']"
      method  += ".register_automate_callback(:first_time_out, 'do_something_great')"
      @ae_method.update_attributes(:data => method)
      @miq_provision[:options][:callbacks].should be_nil
      opts = @miq_provision.options.dup
      opts[:callbacks] = {:next_time_around => 'do_something_better_yet'}
      @miq_provision.update_attributes(:options => opts)
      invoke_ae.root(@ae_result_key).should be_true
      @miq_provision.reload
      callback_hash = @miq_provision[:options][:callbacks]
      callback_hash.count.should  eq(2)
      callback_hash[:first_time_out].should eq('do_something_great')
      callback_hash[:next_time_around].should == 'do_something_better_yet'
    end

    it "#target_type" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision'].target_type"
      @ae_method.update_attributes(:data => method)

      %w{ clone_to_template }.each do |provision_type|
        @miq_provision.update_attributes(:provision_type => provision_type)
        invoke_ae.root(@ae_result_key).should == 'template'
      end

      %w{ template clone_to_vm }.each do |provision_type|
        @miq_provision.update_attributes(:provision_type => provision_type)
        invoke_ae.root(@ae_result_key).should == 'vm'
      end
    end

    context "iso_images" do
      before(:each) do
        @iso_image = FactoryGirl.create(:iso_image, :name => "Test ISO Image")
        iso_image_struct = [MiqHashStruct.new(
                            :id               => "IsoImage::#{@iso_image.id}",
                            :name             => @iso_image.name,
                            :evm_object_class => @iso_image.class.base_class.name.to_sym)
                           ]
        MiqProvisionWorkflow.any_instance.stub(:allowed_iso_images).and_return(iso_image_struct)
      end

      it "eligible_iso_images" do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision'].eligible_iso_images"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        result.should be_kind_of(Array)
        result.first.class.should == MiqAeMethodService::MiqAeServiceIsoImage
      end

      it "set_iso_image" do
        method = <<-AUTOMATE_SCRIPT
          prov = $evm.root['miq_provision']
          prov.eligible_iso_images.each {|iso| prov.set_iso_image(iso)}
        AUTOMATE_SCRIPT
        @ae_method.update_attributes(:data => method)
        invoke_ae.root(@ae_result_key)
        @miq_provision.reload.options[:iso_image_id].should == [@iso_image.id, @iso_image.name]
      end
    end

    context "#source_type" do
      before(:each) do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision'].source_type"
        @ae_method.update_attributes(:data => method)
      end

      it "works with a template" do
        @vm_template.template = true
        @vm_template.save!
        invoke_ae.root(@ae_result_key).should == 'template'
      end

      it "works with a vm" do
        @vm_template.template = false
        @vm_template.save!
        invoke_ae.root(@ae_result_key).should == 'vm'
      end
    end

    context "subclassing" do
      before do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision']"
        @ae_method.update_attributes(:data => method)
      end

      it "return sub class" do
        result = invoke_ae.root(@ae_result_key)
        result.class.should eq MiqAeMethodService::MiqAeServiceManageIQ_Providers_Vmware_InfraManager_Provision
      end

      it "#status" do
        result = invoke_ae.root(@ae_result_key)
        result.status.should eq 'retry'
      end

      it "#associations" do
        result = invoke_ae.root(@ae_result_key)
        result.associations.should_not be_empty
      end

      it "#statemachine_task_status state not finished, status of error returns a retry" do
        @miq_provision.update_attributes(:status => "Error")
        ae_svc_prov.status.should eq('retry')
      end

      it "#statemachine_task_status state not finished, status of ok returns a retry" do
        @miq_provision.update_attributes(:status => "ok")
        ae_svc_prov.status.should eq('retry')
      end

      it "#statemachine_task_status finished state, status of error returns error " do
        @miq_provision.update_attributes(:status => "Error", :state => "finished", :vm => FactoryGirl.create(:vm_vmware))
        ae_svc_prov.status.should eq('error')
      end

      it "#statemachine_task_status finished state, status of ok returns error " do
        @miq_provision.update_attributes(:status => "Ok", :state => "finished")
        ae_svc_prov.status.should eq('error')
      end

      it "#statemachine_task_status finished state, status of ok returns ok " do
        @miq_provision.update_attributes(:status => "Ok", :state => "finished", :vm => FactoryGirl.create(:vm_vmware))
        ae_svc_prov.status.should eq('ok')
      end
    end

    context "customization_templates" do
      before(:each) do
        @ct = FactoryGirl.create(:customization_template, :name => "Test Templates", :script => "script_text")
        ct_struct = [MiqHashStruct.new(:id => @ct.id, :name => @ct.name,
                                       :evm_object_class => @ct.class.base_class.name.to_sym)]
        MiqProvisionWorkflow.any_instance.stub(:allowed_customization_templates).and_return(ct_struct)
      end

      it "#eligible_customization_templates" do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision'].eligible_customization_templates"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        result.should be_kind_of(Array)
        result.first.class.should == MiqAeMethodService::MiqAeServiceCustomizationTemplate
      end

      it "#set_customization_template" do
        method = <<-AUTOMATE_SCRIPT
          prov = $evm.root['miq_provision']
          prov.eligible_customization_templates.each {|ct| prov.set_customization_template(ct)}
        AUTOMATE_SCRIPT
        @ae_method.update_attributes(:data => method)
        invoke_ae.root(@ae_result_key)
        @miq_provision.reload.options[:customization_template_id].should eq([@ct.id, @ct.name])
        @miq_provision.reload.options[:customization_template_script].should eq(@ct.script)
      end
    end

    context "resource_pools" do
      before(:each) do
        @rsc = FactoryGirl.create(:resource_pool)
        MiqProvisionWorkflow.any_instance.stub(:allowed_resource_pools).and_return(@rsc.id => @rsc.name)
        MiqProvisionWorkflow.any_instance.stub(:allowed_respools).and_return(@rsc.id => @rsc.name)
      end

      it "#eligible_resource_pools" do
        method   = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision'].eligible_resource_pools"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        result.should be_kind_of(Array)
        result.first.class.should == MiqAeMethodService::MiqAeServiceResourcePool
      end

      it "#set_resource_pools" do
        method = <<-AUTOMATE_SCRIPT
          prov = $evm.root['miq_provision']
          prov.eligible_resource_pools.each {|rsc| prov.set_resource_pool(rsc)}
        AUTOMATE_SCRIPT
        @ae_method.update_attributes(:data => method)
        invoke_ae.root(@ae_result_key)
        @miq_provision.reload.options[:placement_rp_name].should == [@rsc.id, @rsc.name]
      end
    end
  end
end
