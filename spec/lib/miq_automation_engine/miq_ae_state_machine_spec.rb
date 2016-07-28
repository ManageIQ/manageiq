module MiqAeStateMachineSpec
  include MiqAeEngine
  describe "MiqAeStateMachine" do
    before(:each) do
      @domain = 'SPEC_DOMAIN'
      @user = FactoryGirl.create(:user_with_group)
      @model_data_dir = File.join(File.dirname(__FILE__), "data")
      MiqAeDatastore.reset
    end

    after(:each) do
      MiqAeDatastore.reset
    end

    it "resolves a provision request (old-style)" do
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "state_machine"), @domain)

      t0 = Time.now
      ws = MiqAeEngine.instantiate("/SYSTEM/EVENT/VM_PROVISION_REQUESTED", @user)
      t1 = Time.now

      expect(ws).not_to be_nil
      expect(ws.root['ae_result']).to eq('ok')
      expect(ws.root['ae_state']).to eq('final')

      # puts ws.to_xml
      #     puts "Old Provision Technique took #{t1 - t0} seconds"
    end

    it "resolves a provision request" do
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "state_machine"), @domain)
      MiqAeDatastore.reset_default_namespace

      t0 = Time.now
      ws = MiqAeEngine.instantiate("/SYSTEM/EVENT/VM_PROVISION_REQUESTED_NEW", @user)
      t1 = Time.now

      expect(ws).not_to be_nil
      expect(ws.root['ae_result']).to eq('ok')
      expect(ws.root['ae_state']).to eq('')
      # puts ws.to_xml
      #     puts "New Provision Technique took #{t1 - t0} seconds"
    end

    it "sets error properly during a provision request" do
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "state_machine"), @domain)
      c1 = MiqAeClass.find_by_namespace_and_name("#{@domain}/Factory", "VM")
      i1 = c1.ae_instances.detect { |i| i.name == "ProvisionCheck" }
      f1 = c1.ae_fields.detect    { |f| f.name == "execute"   }
      i1.set_field_attribute(f1, "provision_check(result => 'error')", :value)

      ws = MiqAeEngine.instantiate("/SYSTEM/EVENT/VM_PROVISION_REQUESTED_NEW", @user)

      expect(ws).not_to be_nil
      expect(ws.root['ae_result']).to eq('error')
      expect(ws.root['ae_state']).to eq('ProvisionCheck')
      # puts ws.to_xml
    end

    it "raises exception properly during a provision request" do
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "state_machine"), @domain)

      c1 = MiqAeClass.find_by_namespace_and_name("#{@domain}/Factory", "VM")
      i1 = c1.ae_instances.detect { |i| i.name == "ProvisionCheck" }
      f1 = c1.ae_fields.detect    { |f| f.name == "execute"   }
      i1.set_field_attribute(f1, "provision_check(result => 'exception')", :value)

      ws = MiqAeEngine.instantiate("/SYSTEM/EVENT/VM_PROVISION_REQUESTED_NEW", @user)

      expect(ws).not_to be_nil
      expect(ws.root['ae_result']).to eq('error')
      expect(ws.root['ae_state']).to eq('ProvisionCheck')
      # puts ws.to_xml
    end

    it "properly overrides class values with instance values, when they are present" do
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "state_machine"), @domain)
      t0 = Time.now

      c1 = MiqAeClass.find_by_namespace_and_name("#{@domain}/Factory", "StateMachine")
      i1 = c1.ae_instances.detect { |i| i.name == "Provisioning" }
      f1 = c1.ae_fields.detect    { |f| f.name == "EmailOwner"   }
      i1.set_field_attribute(f1, "log_object", :on_exit)

      ws = MiqAeEngine.instantiate("/SYSTEM/EVENT/VM_PROVISION_REQUESTED_NEW", @user)
      t1 = Time.now

      expect(ws).not_to be_nil
      # puts ws.to_xml
      # puts "New Provision (with instance override) Technique took #{t1 - t0} seconds"
    end

    it "executes on_entry instance methods properly" do
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "state_machine"), @domain)

      c1 = MiqAeClass.find_by_namespace_and_name("#{@domain}/Factory", "StateMachine")
      i1 = c1.ae_instances.detect { |i| i.name == "Provisioning" }
      f1 = c1.ae_fields.detect    { |f| f.name == "AcquireIPAddress"   }
      method_string = "update_provision_status(status => 'Testing on entry method',status_state => 'on_entry')"
      i1.set_field_attribute(f1, method_string, :on_entry)

      ws = MiqAeEngine.instantiate("#{@domain}/Factory/statemachine/Provisioning", @user)
      expect(ws.root("test_root_object_attribute")).to eq("update_provision_status")
    end

    it "sets ae_status_state properly" do
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "state_machine"), @domain)

      ws = MiqAeEngine.instantiate("#{@domain}/Factory/statemachine/Provisioning", @user)
      expect(ws.root['ae_status_state']).to eq('on_exit')
    end

    it "executes on_entry fully qualified class methods properly" do
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "state_machine"), @domain)

      c1 = MiqAeClass.find_by_namespace_and_name("#{@domain}/Factory", "StateMachine")
      i1 = c1.ae_instances.detect { |i| i.name == "Provisioning" }
      f1 = c1.ae_fields.detect    { |f| f.name == "AcquireIPAddress"   }
      method_string = "SPEC_DOMAIN/factory/method.test_class_method(status => 'Testing class on entry method',status_state => 'on_entry')"
      i1.set_field_attribute(f1, method_string, :on_entry)
      ws = MiqAeEngine.instantiate("#{@domain}/Factory/statemachine/Provisioning", @user)
      expect(ws.root("test_root_object_attribute")).to eq("test_class_method")
    end

    it "executes on_entry partially qualified class methods properly" do
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "state_machine"), @domain)

      c1 = MiqAeClass.find_by_namespace_and_name("#{@domain}/Factory", "StateMachine")
      i1 = c1.ae_instances.detect { |i| i.name == "Provisioning" }
      f1 = c1.ae_fields.detect    { |f| f.name == "AcquireIPAddress" }
      method_string = "/factory/method.test_class_method(status => 'Test',status_state => 'on_entry')"
      i1.set_field_attribute(f1, method_string, :on_entry)
      ws = MiqAeEngine.instantiate("#{@domain}/Factory/statemachine/Provisioning", @user)
      expect(ws.root("test_root_object_attribute")).to eq("test_class_method")
    end

    it "executes method:: method properly" do
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "state_machine"), @domain)

      c1 = MiqAeClass.find_by_namespace_and_name("#{@domain}/Factory", "StateMachine")
      i1 = c1.ae_instances.detect { |i| i.name == "Provisioning" }
      f1 = c1.ae_fields.detect    { |f| f.name == "AcquireIPAddress" }
      method_string = "METHOD::update_provision_status(status => 'Test',status_state => 'value')"
      i1.set_field_attribute(f1, method_string, :value)
      ws = MiqAeEngine.instantiate("#{@domain}/Factory/statemachine/Provisioning", @user)
      expect(ws.root("test_root_object_attribute")).to eq("update_provision_status")
    end

    it "executes class method notation method:: properly" do
      EvmSpecHelper.import_yaml_model(File.join(@model_data_dir, "state_machine"), @domain)

      c1 = MiqAeClass.find_by_namespace_and_name("#{@domain}/Factory", "StateMachine")
      i1 = c1.ae_instances.detect { |i| i.name == "Provisioning" }
      f1 = c1.ae_fields.detect    { |f| f.name == "AcquireIPAddress" }
      method_string = "METHOD::/factory/method.test_class_method(status => 'Test',status_state => 'on_entry')"
      i1.set_field_attribute(f1, method_string, :value)
      ws = MiqAeEngine.instantiate("#{@domain}/Factory/statemachine/Provisioning", @user)
      expect(ws.root("test_root_object_attribute")).to eq("test_class_method")
    end
  end
end
