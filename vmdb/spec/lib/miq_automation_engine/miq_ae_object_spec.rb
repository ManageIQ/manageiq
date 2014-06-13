require "spec_helper"

module MiqAeObjectSpec
  include MiqAeEngine
  describe MiqAeObject do
    before(:each) do
      MiqServer.my_server_clear_cache
      MiqAeDatastore.reset
      @domain = 'SPEC_DOMAIN'
      @model_data_dir = File.join(File.dirname(__FILE__), "data")
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "miq_ae_object_spec1"), @domain)
      @vm      = FactoryGirl.create(:vm_vmware)
      @ws      = MiqAeEngine.instantiate("/SYSTEM/EVM/AUTOMATE/test1")
      @miq_obj = MiqAeObject.new(@ws, "#{@domain}/SYSTEM/EVM", "AUTOMATE", "test1")
    end

    after(:each) do
      MiqAeDatastore.reset
    end

    it "#process_args_as_attributes with a hash with no object reference" do
      result = @miq_obj.process_args_as_attributes("name"=> "fred")
      result["name"].should be_kind_of(String)
      result["name"].should == "fred"
    end

    it "#process_args_as_attributes with a hash with an object reference" do
      result = @miq_obj.process_args_as_attributes("VmOrTemplate::vm"=> "#{@vm.id}")
      result["vm_id"].should == @vm.id.to_s
      result["vm"].should be_kind_of(MiqAeMethodService::MiqAeServiceVmOrTemplate)
    end

    it "#process_args_as_attributes with a single element array" do
      result = @miq_obj.process_args_as_attributes({"Array::vms" => "VmOrTemplate::#{@vm.id}"})
      result["vms"].should be_kind_of(Array)
      result["vms"].length.should == 1
    end

    it "#process_args_as_attributes with an array" do
      vm2 = FactoryGirl.create(:vm_vmware)
      result = @miq_obj.process_args_as_attributes({"Array::vms" => "VmOrTemplate::#{@vm.id},VmOrTemplate::#{vm2.id}"})
      result["vms"].should be_kind_of(Array)
      result["vms"].length.should == 2
    end

    it "#process_args_as_attributes with an array containing invalid entries" do
      vm2 = FactoryGirl.create(:vm_vmware)
      result = @miq_obj.process_args_as_attributes({"Array::vms" => "VmOrTemplate::#{@vm.id},fred::12,,VmOrTemplate::#{vm2.id}"})
      result["vms"].should be_kind_of(Array)
      result["vms"].length.should == 2
    end

    it "#process_args_as_attributes with an array containing disparate objects" do
      host    = FactoryGirl.create(:host)
      ems     = FactoryGirl.create(:ems_vmware)
      result  = @miq_obj.process_args_as_attributes({"Array::my_objects" => "VmOrTemplate::#{@vm.id},Host::#{host.id},ExtManagementSystem::#{ems.id}"})
      result["my_objects"].should be_kind_of(Array)
      result["my_objects"].length.should == 3
    end
  
    context "#enforce_state_maxima" do
      it "should not raise an exception before exceeding max_time" do
        Timecop.freeze(Time.parse('2013-01-01 00:59:59 UTC')) do
          @ws.root['ae_state_started'] = '2013-01-01 00:00:00 UTC'
          expect { @miq_obj.enforce_state_maxima({'max_time' => '1.hour'}) }.to_not raise_error
        end
      end

      it "should raise an exception after exceeding max_time" do
        Timecop.freeze(Time.parse('2013-01-01 01:00:00 UTC')) do
          @ws.root['ae_state_started'] = '2013-01-01 00:00:00 UTC'
          expect { @miq_obj.enforce_state_maxima({'max_time' => '1.hour'}) }.to raise_error
        end
      end
    end
  end
end
