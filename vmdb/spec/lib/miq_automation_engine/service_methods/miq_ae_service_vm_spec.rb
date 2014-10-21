require "spec_helper"

module MiqAeServiceVmSpec
  describe MiqAeMethodService::MiqAeServiceVm do
    before(:each) do
      MiqAutomateHelper.create_service_model_method('SPEC_DOMAIN', 'EVM',
                                                    'AUTOMATE', 'test1', 'test')
      @ae_method     = ::MiqAeMethod.find(:first)
      @ae_result_key = 'foo'

      @vm   = FactoryGirl.create(:vm_vmware, :name => "template1", :location => "abc/abc.vmx")
    end

    def invoke_ae
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?Vm::vm=#{@vm.id}")
    end

    it "#ems_custom_keys" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['vm'].ems_custom_keys"
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      ae_object.should be_kind_of(Array)
      ae_object.should be_empty

      key1   = 'key1'
      value1 = 'value1'
      c1 = FactoryGirl.create(:ems_custom_attribute, :resource => @vm, :name => key1, :value => value1)
      ae_object = invoke_ae.root(@ae_result_key)
      ae_object.should be_kind_of(Array)
      ae_object.length.should == 1
      ae_object.first.should == key1

      key2   = 'key2'
      value2 = 'value2'
      c1 = FactoryGirl.create(:ems_custom_attribute, :resource => @vm, :name => key2, :value => value2)
      ae_object = invoke_ae.root(@ae_result_key)
      ae_object.should be_kind_of(Array)
      ae_object.length.should == 2
      ae_object.sort.should == [key1, key2]
    end

    it "#ems_custom_get" do
      key    = 'key1'
      value  = 'value1'
      method = "$evm.root['#{@ae_result_key}'] = $evm.root['vm'].ems_custom_get('#{key}')"
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      ae_object.should be_nil

      c1 = FactoryGirl.create(:ems_custom_attribute, :resource => @vm, :name => key, :value => value)
      ae_object = invoke_ae.root(@ae_result_key)
      ae_object.should == value
    end

    it "#remove_from_vmdb" do
      VmOrTemplate.count.should == 1
      method = "$evm.root['#{@ae_result_key}'] = $evm.root['vm'].remove_from_vmdb"
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      VmOrTemplate.count.should == 0
    end

    context "with a service" do
      before(:each) do
        @service = FactoryGirl.create(:service)
      end

      context "#add_to_service" do
        it "without a service relationship" do
          method = "$evm.root['#{@ae_result_key}'] = $evm.root['vm'].add_to_service($evm.vmdb('service').first)"
          @ae_method.update_attributes(:data => method)
          ae_object = invoke_ae.root(@ae_result_key)

          ae_object.should be_kind_of(MiqAeMethodService::MiqAeServiceServiceResource)
          @service.vms.count.should == 1
        end

        it "with an existing service relationship" do
          @service.add_resource!(@vm)
          method = "$evm.root['#{@ae_result_key}'] = $evm.root['vm'].add_to_service($evm.vmdb('service').first)"
          @ae_method.update_attributes(:data => method)

          expect {invoke_ae.root(@ae_result_key)}.to raise_error(MiqAeException::AbortInstantiation)
        end
      end

      context "#remove_from_service" do
        it "without a service relationship" do
          method = "$evm.root['#{@ae_result_key}'] = $evm.root['vm'].remove_from_service"
          @ae_method.update_attributes(:data => method)

          invoke_ae.root(@ae_result_key).should be_nil
        end

        it "with an existing service relationship" do
          @service.add_resource!(@vm)
          method = "$evm.root['#{@ae_result_key}'] = $evm.root['vm'].remove_from_service"
          @ae_method.update_attributes(:data => method)

          invoke_ae.root(@ae_result_key).should be_kind_of(MiqAeMethodService::MiqAeServiceServiceResource)
        end
      end
    end
  end
end
