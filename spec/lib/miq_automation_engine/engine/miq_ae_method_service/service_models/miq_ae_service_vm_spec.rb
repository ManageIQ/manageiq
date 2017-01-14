module MiqAeServiceVmSpec
  describe MiqAeMethodService::MiqAeServiceVm do
    let(:vm)         { FactoryGirl.create(:vm_vmware, :name => "template1", :location => "abc/abc.vmx") }
    let(:service_vm) { MiqAeMethodService::MiqAeServiceManageIQ_Providers_Vmware_InfraManager_Vm.find(vm.id) }

    before(:each) do
      @user = FactoryGirl.create(:user_with_group)
      Spec::Support::MiqAutomateHelper.create_service_model_method('SPEC_DOMAIN', 'EVM', 'AUTOMATE', 'test1', 'test')
      @ae_method     = ::MiqAeMethod.first
      @ae_result_key = 'foo'

      @vm   = FactoryGirl.create(:vm_vmware, :name => "template1", :location => "abc/abc.vmx")
      allow(MiqServer).to receive(:my_zone).and_return('default')
    end

    def invoke_ae
      MiqAeEngine.instantiate("/EVM/AUTOMATE/test1?Vm::vm=#{@vm.id}", @user)
    end

    it "#ems_custom_keys" do
      method   = "$evm.root['#{@ae_result_key}'] = $evm.root['vm'].ems_custom_keys"
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      expect(ae_object).to be_kind_of(Array)
      expect(ae_object).to be_empty

      key1   = 'key1'
      value1 = 'value1'
      c1 = FactoryGirl.create(:ems_custom_attribute, :resource => @vm, :name => key1, :value => value1)
      ae_object = invoke_ae.root(@ae_result_key)
      expect(ae_object).to be_kind_of(Array)
      expect(ae_object.length).to eq(1)
      expect(ae_object.first).to eq(key1)

      key2   = 'key2'
      value2 = 'value2'
      c1 = FactoryGirl.create(:ems_custom_attribute, :resource => @vm, :name => key2, :value => value2)
      ae_object = invoke_ae.root(@ae_result_key)
      expect(ae_object).to be_kind_of(Array)
      expect(ae_object.length).to eq(2)
      expect(ae_object.sort).to eq([key1, key2])
    end

    it "#ems_custom_get" do
      key    = 'key1'
      value  = 'value1'
      method = "$evm.root['#{@ae_result_key}'] = $evm.root['vm'].ems_custom_get('#{key}')"
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      expect(ae_object).to be_nil

      c1 = FactoryGirl.create(:ems_custom_attribute, :resource => @vm, :name => key, :value => value)
      ae_object = invoke_ae.root(@ae_result_key)
      expect(ae_object).to eq(value)
    end

    it "#remove_from_vmdb" do
      expect(VmOrTemplate.count).to eq(1)
      method = "$evm.root['#{@ae_result_key}'] = $evm.root['vm'].remove_from_vmdb"
      @ae_method.update_attributes(:data => method)
      ae_object = invoke_ae.root(@ae_result_key)
      expect(VmOrTemplate.count).to eq(0)
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

          expect(ae_object).to be_kind_of(MiqAeMethodService::MiqAeServiceServiceResource)
          expect(@service.vms.count).to eq(1)
        end

        it "with an existing service relationship" do
          @service.add_resource!(@vm)
          method = "$evm.root['#{@ae_result_key}'] = $evm.root['vm'].add_to_service($evm.vmdb('service').first)"
          @ae_method.update_attributes(:data => method)

          expect { invoke_ae.root(@ae_result_key) }.to raise_error(MiqAeException::AbortInstantiation)
        end
      end

      context "#remove_from_service" do
        it "without a service relationship" do
          method = "$evm.root['#{@ae_result_key}'] = $evm.root['vm'].remove_from_service"
          @ae_method.update_attributes(:data => method)

          expect(invoke_ae.root(@ae_result_key)).to be_nil
        end

        it "with an existing service relationship" do
          @service.add_resource!(@vm)
          method = "$evm.root['#{@ae_result_key}'] = $evm.root['vm'].remove_from_service"
          @ae_method.update_attributes(:data => method)

          expect(invoke_ae.root(@ae_result_key)).to be_kind_of(MiqAeMethodService::MiqAeServiceServiceResource)
        end
      end
    end

    it "#start_retirement" do
      expect(service_vm.retirement_state).to be_nil
      service_vm.start_retirement
      expect(service_vm.retirement_state).to eq("retiring")
    end

    it "#retire_now" do
      expect(MiqEvent).to receive(:raise_evm_event).once

      service_vm.retire_now
    end

    it "#finish_retirement" do
      expect(service_vm.retired).to be_nil
      expect(service_vm.retirement_state).to be_nil
      expect(service_vm.retires_on).to be_nil

      service_vm.finish_retirement

      expect(service_vm.retired).to be_truthy
      expect(service_vm.retires_on).to be_between(Time.zone.now - 1.hour, Time.zone.now + 1.second)
      expect(service_vm.retirement_state).to eq("retired")
    end

    it "#retiring? - false" do
      expect(service_vm.retiring?).to be_falsey
    end

    it "#retiring - true" do
      service_vm.retirement_state = 'retiring'

      expect(service_vm.retiring?).to be_truthy
    end

    it "#error_retiring? - false" do
      expect(service_vm.error_retiring?).to be_falsey
    end

    it "#error_retiring - true" do
      service_vm.retirement_state = 'error'

      expect(service_vm.error_retiring?).to be_truthy
    end

    it "#retires_on - today" do
      vm.update_attributes(:retirement_last_warn => Date.today)
      service_vm.retires_on = Time.zone.today

      vm.reload
      expect(vm.retirement_last_warn).to be_nil
      expect(vm.retirement_due?).to be_truthy
    end

    it "#retires_on - tomorrow" do
      vm.update_attributes(
        :retired              => true,
        :retirement_last_warn => Time.zone.today,
        :retirement_state     => "retiring"
      )
      service_vm.retires_on = Time.zone.today + 1
      vm.reload

      expect(vm).to have_attributes(
        :retirement_last_warn => nil,
        :retired              => false,
        :retirement_state     => nil,
        :retirement_due?      => false
      )
    end

    it "#extend_retires_on - no retirement date set" do
      Timecop.freeze(Time.zone.today) do
        extend_days = 7
        service_vm.extend_retires_on(extend_days)
        vm.reload
        new_retires_on = Time.zone.today + extend_days
        expect(vm.retires_on.day).to eq(new_retires_on.day)
      end
    end

    it "#extend_retires_on - future retirement date set" do
      Timecop.freeze(Time.zone.today) do
        vm.update_attributes(
          :retired              => true,
          :retirement_last_warn => Time.zone.today,
          :retirement_state     => "retiring"
        )
        future_retires_on = Time.zone.today + 30
        service_vm.retires_on = future_retires_on
        extend_days = 7
        service_vm.extend_retires_on(extend_days, future_retires_on)
        vm.reload

        expect(vm).to have_attributes(
          :retirement_last_warn => nil,
          :retired              => false,
          :retirement_state     => nil,
          :retires_on           => future_retires_on + extend_days
        )
      end
    end

    it "#retirement_warn" do
      expect(service_vm.retirement_warn).to be_nil
      vm.retirement_last_warn = Date.today
      service_vm.retirement_warn = 60

      vm.reload

      expect(service_vm.retirement_warn).to eq(60)
      expect(vm.retirement_last_warn).to be_nil
    end

    context "#create_snapshot" do
      it "without memory" do
        service_vm.create_snapshot('snap', 'crackle & pop')

        expect(MiqQueue.first.args.first).to have_attributes(
          :task        => 'create_snapshot',
          :memory      => false,
          :name        => 'snap',
          :description => 'crackle & pop'
        )
      end

      it "with memory" do
        service_vm.create_snapshot('snap', 'crackle & pop', true)

        expect(MiqQueue.first.args.first).to have_attributes(
          :task        => 'create_snapshot',
          :memory      => true,
          :name        => 'snap',
          :description => 'crackle & pop'
        )
      end

      it "when not supported" do
        vm_amazon = FactoryGirl.create(:vm_amazon, :name => "template1")
        svc_vm = MiqAeMethodService::MiqAeServiceManageIQ_Providers_Amazon_CloudManager_Vm.find(vm_amazon.id)

        expect { svc_vm.create_snapshot('snap', 'crackle & pop') }.to raise_error(RuntimeError)
      end
    end
  end
end
