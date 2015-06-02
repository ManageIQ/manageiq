require "spec_helper"

module MiqAeServiceVmSpec
  describe MiqAeMethodService::MiqAeServiceVm do

    let(:vm)         { FactoryGirl.create(:vm_vmware, :name => "template1", :location => "abc/abc.vmx") }
    let(:service_vm) { MiqAeMethodService::MiqAeServiceVmVmware.find(vm.id) }

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

    it "#start_retirement" do
      expect(service_vm.retirement_state).to be_nil
      service_vm.start_retirement
      expect(service_vm.retirement_state).to eq("retiring")
    end

    it "#retire_now" do
      expect(MiqAeEvent).to receive(:raise_evm_event).once

      service_vm.retire_now
    end

    it "#finish_retirement" do
      expect(service_vm.retired).to be_nil
      expect(service_vm.retirement_state).to be_nil
      expect(service_vm.retires_on).to be_nil

      service_vm.finish_retirement

      expect(service_vm.retired).to be_true
      expect(service_vm.retires_on).to eq(Date.today)
      expect(service_vm.retirement_state).to eq("retired")
    end

    it "#retiring? - false" do
      expect(service_vm.retiring?).to be_false
    end

    it "#retiring - true" do
      service_vm.retirement_state = 'retiring'

      expect(service_vm.retiring?).to be_true
    end

    it "#error_retiring? - false" do
      expect(service_vm.error_retiring?).to be_false
    end

    it "#error_retiring - true" do
      service_vm.retirement_state = 'error'

      expect(service_vm.error_retiring?).to be_true
    end

    it "#retires_on - today" do
      service_vm.retires_on = Date.today
      vm.reload

      expect(vm.retirement_due?).to be_true
    end

    it "#retires_on - tomorrow" do
      service_vm.retires_on = Date.today + 1
      vm.reload

      expect(vm.retirement_due?).to be_false
    end

    it "#retirement_warn" do
      expect(service_vm.retirement_warn).to be_nil
      vm.retirement_last_warn = Date.today
      service_vm.retirement_warn = 60

      vm.reload

      expect(service_vm.retirement_warn).to eq(60)
      expect(vm.retirement_last_warn).to be_nil
    end
  end
end
