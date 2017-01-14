module MiqAeServiceManageIQ_Providers_Vmware_InfraManager_ProvisionSpec
  describe MiqAeMethodService::MiqAeServiceManageIQ_Providers_Vmware_InfraManager_Provision do
    before(:each) do
      Spec::Support::MiqAutomateHelper.create_service_model_method('SPEC_DOMAIN', 'EVM', 'AUTOMATE', 'test1', 'test')
      @ae_method     = ::MiqAeMethod.first
      @ae_result_key = 'foo'

      @ems           = FactoryGirl.create(:ems_vmware_with_authentication)
      @vm_template   = FactoryGirl.create(:template_vmware, :ext_management_system => @ems)
      @options       = {}
      @options[:src_vm_id] = [@vm_template.id, @vm_template.name]
      @options[:pass]      = 1
      @user = FactoryGirl.create(:user_with_group, :name => 'Fred Flintstone', :userid => 'fred')
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
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?#{target_key}=#{target_value}", @user)
    end

    context "check requests" do
      before(:each) do
        @miq_provision_request = FactoryGirl.create(:miq_provision_request,
                                                    :provision_type => 'template',
                                                    :state => 'pending', :status => 'Ok',
                                                    :src_vm_id => @vm_template.id,
                                                    :requester => @user)
        @miq_provision.miq_provision_request = @miq_provision_request
        @miq_provision.save!
        @miq_provision_request.save!
      end

      it "#miq_request" do
        method = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision'].miq_request"
        @ae_method.update_attributes(:data => method)
        ae_object = invoke_ae.root(@ae_result_key)
        expect(ae_object).to be_kind_of(MiqAeMethodService::MiqAeServiceMiqRequest)
        expect(ae_object.id).to eq(@miq_provision_request.id)
      end

      it "#miq_provision_request" do
        method = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision'].miq_provision_request"
        @ae_method.update_attributes(:data => method)
        ae_object = invoke_ae.root(@ae_result_key)
        expect(ae_object).to be_kind_of(MiqAeMethodService::MiqAeServiceMiqProvisionRequest)
        [:id, :provision_type, :state, :status, :src_vm_id, :userid].each do |meth|
          expect(ae_object.send(meth)).to eq(@miq_provision_request.send(meth))
        end
      end
    end

    it "#vm" do
      method = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision'].vm"
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      expect(ae_object).to be_nil

      vm = FactoryGirl.create(:vm_vmware, :name => "vm42", :location => "vm42/vm42.vmx")
      @miq_provision.vm = vm
      @miq_provision.save!

      ae_object = invoke_ae.root(@ae_result_key)
      expect(ae_object).to be_kind_of(MiqAeMethodService::MiqAeServiceVm)
      [:id, :name, :location].each { |meth| expect(ae_object.send(meth)).to eq(vm.send(meth)) }
    end

    it "#vm_template" do
      method = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision'].vm_template"
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      expect(ae_object).to be_kind_of(MiqAeMethodService::MiqAeServiceMiqTemplate)
      [:id, :name, :location].each { |meth| expect(ae_object.send(meth)).to eq(@vm_template.send(meth)) }
    end

    it "#execute" do
      method = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision'].execute"
      @ae_method.update_attributes(:data => method)

      expect_any_instance_of(MiqProvision).to receive(:execute_queue).once
      expect(invoke_ae.root(@ae_result_key)).to be_truthy
    end

    it "#request_type" do
      method = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision'].request_type"
      @ae_method.update_attributes(:data => method)

      %w( template clone_to_vm clone_to_template ).each do |provision_type|
        @miq_provision.update_attributes(:provision_type => provision_type)
        expect(invoke_ae.root(@ae_result_key)).to eq(@miq_provision.provision_type)
      end
    end

    it "#register_automate_callback - no previous callbacks" do
      method = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision']"
      method += ".register_automate_callback(:first_time_out, 'do_something_great')"
      @ae_method.update_attributes(:data => method)
      expect(invoke_ae.root(@ae_result_key)).to be_truthy
      expect(@miq_provision[:options][:callbacks]).to be_nil
      @miq_provision.reload
      callback_hash = @miq_provision[:options][:callbacks]
      expect(callback_hash.count).to eq(1)
      expect(callback_hash[:first_time_out]).to eq('do_something_great')
    end

    it "#register_automate_callback - with previous callbacks" do
      method = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision']"
      method += ".register_automate_callback(:first_time_out, 'do_something_great')"
      @ae_method.update_attributes(:data => method)
      expect(@miq_provision[:options][:callbacks]).to be_nil
      opts = @miq_provision.options.dup
      opts[:callbacks] = {:next_time_around => 'do_something_better_yet'}
      @miq_provision.update_attributes(:options => opts)
      expect(invoke_ae.root(@ae_result_key)).to be_truthy
      @miq_provision.reload
      callback_hash = @miq_provision[:options][:callbacks]
      expect(callback_hash.count).to eq(2)
      expect(callback_hash[:first_time_out]).to eq('do_something_great')
      expect(callback_hash[:next_time_around]).to eq('do_something_better_yet')
    end

    it "#target_type" do
      method = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision'].target_type"
      @ae_method.update_attributes(:data => method)

      %w( clone_to_template ).each do |provision_type|
        @miq_provision.update_attributes(:provision_type => provision_type)
        expect(invoke_ae.root(@ae_result_key)).to eq('template')
      end

      %w( template clone_to_vm ).each do |provision_type|
        @miq_provision.update_attributes(:provision_type => provision_type)
        expect(invoke_ae.root(@ae_result_key)).to eq('vm')
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
        allow_any_instance_of(MiqProvisionWorkflow).to receive(:allowed_iso_images).and_return(iso_image_struct)
      end

      it "eligible_iso_images" do
        method = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision'].eligible_iso_images"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        expect(result).to be_kind_of(Array)
        expect(result.first.class).to eq(MiqAeMethodService::MiqAeServiceIsoImage)
      end

      it "set_iso_image" do
        method = <<-AUTOMATE_SCRIPT
          prov = $evm.root['miq_provision']
          prov.eligible_iso_images.each {|iso| prov.set_iso_image(iso)}
        AUTOMATE_SCRIPT
        @ae_method.update_attributes(:data => method)
        invoke_ae.root(@ae_result_key)
        expect(@miq_provision.reload.options[:iso_image_id]).to eq([@iso_image.id, @iso_image.name])
      end
    end

    context "#source_type" do
      before(:each) do
        method = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision'].source_type"
        @ae_method.update_attributes(:data => method)
      end

      it "works with a template" do
        @vm_template.template = true
        @vm_template.save!
        expect(invoke_ae.root(@ae_result_key)).to eq('template')
      end

      it "works with a vm" do
        @vm_template.template = false
        @vm_template.save!
        expect(invoke_ae.root(@ae_result_key)).to eq('vm')
      end
    end

    context "subclassing" do
      before do
        method = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision']"
        @ae_method.update_attributes(:data => method)
      end

      it "return sub class" do
        result = invoke_ae.root(@ae_result_key)
        expect(result.class).to eq MiqAeMethodService::MiqAeServiceManageIQ_Providers_Vmware_InfraManager_Provision
      end

      it "#status" do
        result = invoke_ae.root(@ae_result_key)
        expect(result.status).to eq 'retry'
      end

      it "#associations" do
        result = invoke_ae.root(@ae_result_key)
        expect(result.associations).not_to be_empty
      end

      it "#statemachine_task_status state not finished, status of error returns a retry" do
        @miq_provision.update_attributes(:status => "Error")
        expect(ae_svc_prov.status).to eq('retry')
      end

      it "#statemachine_task_status state not finished, status of ok returns a retry" do
        @miq_provision.update_attributes(:status => "ok")
        expect(ae_svc_prov.status).to eq('retry')
      end

      it "#statemachine_task_status finished state, status of error returns error " do
        @miq_provision.update_attributes(:status => "Error", :state => "finished",
                                         :vm => FactoryGirl.create(:vm_vmware))
        expect(ae_svc_prov.status).to eq('error')
      end

      it "#statemachine_task_status finished state, status of ok returns error " do
        @miq_provision.update_attributes(:status => "Ok", :state => "finished")
        expect(ae_svc_prov.status).to eq('error')
      end

      it "#statemachine_task_status finished state, status of ok returns ok " do
        @miq_provision.update_attributes(:status => "Ok", :state => "finished", :vm => FactoryGirl.create(:vm_vmware))
        expect(ae_svc_prov.status).to eq('ok')
      end
    end

    context "customization_templates" do
      before(:each) do
        @ct = FactoryGirl.create(:customization_template, :name => "Test Templates", :script => "script_text")
        ct_struct = [MiqHashStruct.new(:id => @ct.id, :name => @ct.name,
                                       :evm_object_class => @ct.class.base_class.name.to_sym)]
        allow_any_instance_of(MiqProvisionWorkflow).to receive(:allowed_customization_templates).and_return(ct_struct)
      end

      it "#eligible_customization_templates" do
        method = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision'].eligible_customization_templates"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        expect(result).to be_kind_of(Array)
        expect(result.first.class).to eq(MiqAeMethodService::MiqAeServiceCustomizationTemplate)
      end

      it "#set_customization_template" do
        method = <<-AUTOMATE_SCRIPT
          prov = $evm.root['miq_provision']
          prov.eligible_customization_templates.each {|ct| prov.set_customization_template(ct)}
        AUTOMATE_SCRIPT
        @ae_method.update_attributes(:data => method)
        invoke_ae.root(@ae_result_key)
        expect(@miq_provision.reload.options[:customization_template_id]).to eq([@ct.id, @ct.name])
        expect(@miq_provision.reload.options[:customization_template_script]).to eq(@ct.script)
      end
    end

    context "customization_specs" do
      before(:each) do
        @cs = FactoryGirl.create(:customization_spec, :name => "Test Specs", :spec => {"script_text" => "blah"})
        cs_struct = [MiqHashStruct.new(:id => @cs.id, :name => @cs.name,
                                       :evm_object_class => @cs.class.base_class.name.to_sym)]
        allow_any_instance_of(MiqProvisionVirtWorkflow).to receive(:allowed_customization_specs).and_return(cs_struct)

        allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager::ProvisionWorkflow)
          .to receive(:get_dialogs).and_return(:dialogs => {})
        allow_any_instance_of(MiqRequestWorkflow).to receive(:normalize_numeric_fields)
        allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager::ProvisionWorkflow).to receive(:update_field_visibility)
      end

      it "#eligible_customization_specs" do
        method = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision'].eligible_customization_specs"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        expect(result).to be_kind_of(Array)
        expect(result.first.class).to eq(MiqAeMethodService::MiqAeServiceCustomizationSpec)
      end

      it "#set_customization_spec" do
        method = <<-AUTOMATE_SCRIPT
          prov = $evm.root['miq_provision']
          prov.eligible_customization_specs.each {|cs| prov.set_customization_spec(cs)}
        AUTOMATE_SCRIPT
        @ae_method.update_attributes(:data => method)
        invoke_ae.root(@ae_result_key)
        expect(@miq_provision.reload.options[:sysprep_custom_spec]).to eq([@cs.id, @cs.name])
        expect(@miq_provision.reload.options[:sysprep_enabled]).to eq(%w(fields Specification))
      end

      it "#set_customization_spec passing the name of the spec" do
        method = <<-AUTOMATE_SCRIPT
          prov = $evm.root['miq_provision']
          prov.eligible_customization_specs.each {|cs| prov.set_customization_spec(cs.name)}
        AUTOMATE_SCRIPT
        @ae_method.update_attributes(:data => method)
        invoke_ae.root(@ae_result_key)
        expect(@miq_provision.reload.options[:sysprep_custom_spec]).to eq([@cs.id, @cs.name])
        expect(@miq_provision.reload.options[:sysprep_enabled]).to eq(%w(fields Specification))
      end
    end

    context "storage_profiles" do
      let(:storage_profile) { FactoryGirl.create(:storage_profile, :name => "Test StorageProfile", :ems_id => @ems.id) }

      before(:each) do
        @vm_template.storage_profile = storage_profile
      end

      it "#eligible_storage_profiles" do
        method = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision'].eligible_storage_profiles"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        expect(result).to be_kind_of(Array)
        expect(result.first.class).to eq(MiqAeMethodService::MiqAeServiceStorageProfile)
      end

      it "#set_storage_profiles" do
        method = <<-AUTOMATE_SCRIPT
          prov = $evm.root['miq_provision']
          prov.eligible_storage_profiles.each {|sp| prov.set_storage_profile(sp)}
        AUTOMATE_SCRIPT
        @ae_method.update_attributes(:data => method)
        invoke_ae.root(@ae_result_key)
        expect(@miq_provision.reload.options[:placement_storage_profile]).to eq(
          [storage_profile.id, storage_profile.name]
        )
      end
    end

    context "resource_pools" do
      before(:each) do
        @rsc = FactoryGirl.create(:resource_pool)
        allow_any_instance_of(MiqProvisionWorkflow).to receive(:allowed_resource_pools).and_return(@rsc.id => @rsc.name)
        allow_any_instance_of(MiqProvisionWorkflow).to receive(:allowed_respools).and_return(@rsc.id => @rsc.name)
      end

      it "#eligible_resource_pools" do
        method = "$evm.root['#{@ae_result_key}'] = $evm.root['miq_provision'].eligible_resource_pools"
        @ae_method.update_attributes(:data => method)
        result = invoke_ae.root(@ae_result_key)
        expect(result).to be_kind_of(Array)
        expect(result.first.class).to eq(MiqAeMethodService::MiqAeServiceResourcePool)
      end

      it "#set_resource_pools" do
        method = <<-AUTOMATE_SCRIPT
          prov = $evm.root['miq_provision']
          prov.eligible_resource_pools.each {|rsc| prov.set_resource_pool(rsc)}
        AUTOMATE_SCRIPT
        @ae_method.update_attributes(:data => method)
        invoke_ae.root(@ae_result_key)
        expect(@miq_provision.reload.options[:placement_rp_name]).to eq([@rsc.id, @rsc.name])
      end
    end
  end
end
