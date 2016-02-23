include AutomationSpecHelper

module MiqAeObjectSpec
  include MiqAeEngine
  describe MiqAeObject do
    before(:each) do
      MiqAeDatastore.reset
      @domain = 'SPEC_DOMAIN'
      @user = FactoryGirl.create(:user_with_group)
      @model_data_dir = File.join(File.dirname(__FILE__), "data")
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "miq_ae_object_spec1"), @domain)
      @vm      = FactoryGirl.create(:vm_vmware)
      @ws      = MiqAeEngine.instantiate("/SYSTEM/EVM/AUTOMATE/test1", @user)
      @miq_obj = MiqAeObject.new(@ws, "#{@domain}/SYSTEM/EVM", "AUTOMATE", "test1")
    end

    after(:each) do
      MiqAeDatastore.reset
    end

    it "#to_xml" do
      args = {'nil_arg' => nil, 'float_arg' => 5.98,
              'int_arg' => 10,  'string_arg' => 'Stringy',
              'svc_vm'  => MiqAeMethodService::MiqAeServiceManageIQ_Providers_Vmware_InfraManager_Vm.find(@vm.id)}

      @miq_obj.process_args_as_attributes(args)
      validate_xml(@miq_obj.to_xml, args)
    end

    def validate_xml(xml, args)
      hash = Hash.from_xml(xml)
      attrs = hash['MiqAeObject']['MiqAeAttribute']
      args.each do |key, value|
        expect(find_match(attrs, key, value)).to be_truthy
      end
    end

    def find_match(attrs, key, value)
      item = attrs.detect { |i| i['name'] == key }
      return false unless item
      item.delete('name')
      xml_class = item.keys.first
      type_match(value.class, xml_class) &&
        value_match(value, item[xml_class])
    end

    def type_match(original_class, xml_class_name)
      xml_class_name = xml_class_name.gsub(/-/, '::')
      /MiqAeMethodService::(?<cls>.*)/ =~ original_class.name
      cls &&= "MiqAeMethodService::#{xml_class_name}"
      cls ||= xml_class_name
      original_class == cls.constantize
    end

    def value_match(value, xml_value)
      service_model = value.class.name.start_with?("MiqAeMethodService::")
      return value.id.inspect == xml_value['id'] if service_model
      value == xml_value || value.inspect == xml_value
    end

    it "#process_args_as_attributes with a hash with no object reference" do
      result = @miq_obj.process_args_as_attributes("name" => "fred")
      expect(result["name"]).to be_kind_of(String)
      expect(result["name"]).to eq("fred")
    end

    it "#process_args_as_attributes with a hash with an object reference" do
      result = @miq_obj.process_args_as_attributes("VmOrTemplate::vm" => "#{@vm.id}")
      expect(result["vm_id"]).to eq(@vm.id.to_s)
      expect(result["vm"]).to be_kind_of(MiqAeMethodService::MiqAeServiceVmOrTemplate)
    end

    it "#process_args_as_attributes with a single element array" do
      result = @miq_obj.process_args_as_attributes({"Array::vms" => "VmOrTemplate::#{@vm.id}"})
      expect(result["vms"]).to be_kind_of(Array)
      expect(result["vms"].length).to eq(1)
    end

    it "#process_args_as_attributes with an array" do
      vm2 = FactoryGirl.create(:vm_vmware)
      result = @miq_obj.process_args_as_attributes({"Array::vms" => "VmOrTemplate::#{@vm.id},VmOrTemplate::#{vm2.id}"})
      expect(result["vms"]).to be_kind_of(Array)
      expect(result["vms"].length).to eq(2)
    end

    it "#process_args_as_attributes with an array containing invalid entries" do
      vm2 = FactoryGirl.create(:vm_vmware)
      result = @miq_obj.process_args_as_attributes({"Array::vms" => "VmOrTemplate::#{@vm.id},fred::12,,VmOrTemplate::#{vm2.id}"})
      expect(result["vms"]).to be_kind_of(Array)
      expect(result["vms"].length).to eq(2)
    end

    it "#process_args_as_attributes with an array containing disparate objects" do
      host    = FactoryGirl.create(:host)
      ems     = FactoryGirl.create(:ems_vmware)
      result  = @miq_obj.process_args_as_attributes({"Array::my_objects" => "VmOrTemplate::#{@vm.id},Host::#{host.id},ExtManagementSystem::#{ems.id}"})
      expect(result["my_objects"]).to be_kind_of(Array)
      expect(result["my_objects"].length).to eq(3)
    end

    it "disabled inheritance" do
      @user = FactoryGirl.create(:user_with_group)
      create_state_ae_model(:name => 'LUIGI', :ae_class => 'CLASS1', :ae_namespace => 'A/C', :instance_name => 'FRED')
      klass = MiqAeClass.find_by_name('CLASS1')
      klass.update_attributes!(:inherits => '/LUIGI/A/C/missing')
      workspace = MiqAeEngine.instantiate("/A/C/CLASS1/FRED", @user)
      expect(workspace.root).not_to be_nil
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
          expect { @miq_obj.enforce_state_maxima('max_time' => '1.hour') }
            .to raise_error(RuntimeError, /exceeded maximum/)
        end
      end
    end
  end
end
