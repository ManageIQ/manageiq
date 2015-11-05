require "spec_helper"

describe Vm do
  it "#corresponding_model" do
    Vm.corresponding_model.should == MiqTemplate
    ManageIQ::Providers::Vmware::InfraManager::Vm.corresponding_model.should == ManageIQ::Providers::Vmware::InfraManager::Template
    ManageIQ::Providers::Redhat::InfraManager::Vm.corresponding_model.should == ManageIQ::Providers::Redhat::InfraManager::Template
  end

  it "#corresponding_template_model" do
    Vm.corresponding_template_model.should == MiqTemplate
    ManageIQ::Providers::Vmware::InfraManager::Vm.corresponding_template_model.should == ManageIQ::Providers::Vmware::InfraManager::Template
    ManageIQ::Providers::Redhat::InfraManager::Vm.corresponding_template_model.should == ManageIQ::Providers::Redhat::InfraManager::Template
  end

  context "#template=" do
    before(:each) { @vm = FactoryGirl.create(:vm_vmware) }

    it "false" do
      @vm.update_attribute(:template, false)
      @vm.type.should == "ManageIQ::Providers::Vmware::InfraManager::Vm"
      @vm.template.should == false
      @vm.state.should == "on"
      -> { @vm.reload }.should_not raise_error
      -> { ManageIQ::Providers::Vmware::InfraManager::Template.find(@vm.id) }.should raise_error ActiveRecord::RecordNotFound
    end

    it "true" do
      @vm.update_attribute(:template, true)
      @vm.type.should == "ManageIQ::Providers::Vmware::InfraManager::Template"
      @vm.template.should == true
      @vm.state.should == "never"
      -> { @vm.reload }.should raise_error ActiveRecord::RecordNotFound
      -> { ManageIQ::Providers::Vmware::InfraManager::Template.find(@vm.id) }.should_not raise_error
    end
  end

  it "#validate_remote_console_vmrc_support only suppored on vmware" do
    vm = FactoryGirl.create(:vm_redhat, :vendor => "redhat")
    -> { vm.validate_remote_console_vmrc_support }.should raise_error MiqException::RemoteConsoleNotSupportedError
  end

  context ".find_all_by_mac_address_and_hostname_and_ipaddress" do
    before do
      @hardware1 = FactoryGirl.create(:hardware)
      @vm1 = FactoryGirl.create(:vm_vmware, :hardware => @hardware1)

      @hardware2 = FactoryGirl.create(:hardware)
      @vm2 = FactoryGirl.create(:vm_vmware, :hardware => @hardware2)
    end

    it "mac_address" do
      address = "ABCDEFG"
      guest_device = FactoryGirl.create(:guest_device, :address => address, :device_type => "ethernet")
      @hardware1.guest_devices << guest_device

      expect(described_class.find_all_by_mac_address_and_hostname_and_ipaddress(address, nil, nil))
        .to eql([@vm1])
    end

    it "hostname" do
      hostname = "ABCDEFG"
      network = FactoryGirl.create(:network, :hostname => hostname)
      @hardware1.networks << network

      expect(described_class.find_all_by_mac_address_and_hostname_and_ipaddress(nil, hostname, nil))
        .to eql([@vm1])
    end

    it "ipaddress" do
      ipaddress = "127.0.0.1"
      network = FactoryGirl.create(:network, :ipaddress => ipaddress)
      @hardware1.networks << network

      expect(described_class.find_all_by_mac_address_and_hostname_and_ipaddress(nil, nil, ipaddress))
        .to eql([@vm1])
    end

    it "returns an empty list when all are blank" do
      expect(described_class.find_all_by_mac_address_and_hostname_and_ipaddress(nil, nil, nil)).to eq([])
      expect(described_class.find_all_by_mac_address_and_hostname_and_ipaddress('', '', '')).to eq([])
    end
  end

  context "with relationships of multiple types" do
    before(:each) do
      @rp        = FactoryGirl.create(:resource_pool, :name => "RP")
      @parent_vm = FactoryGirl.create(:vm_vmware, :name => "Parent VM")
      @vm        = FactoryGirl.create(:vm_vmware, :name => "VM")
      @child_vm  = FactoryGirl.create(:vm_vmware, :name => "Child VM")

      @rp.with_relationship_type("ems_metadata")     { @rp.add_child(@vm) }
      @parent_vm.with_relationship_type("genealogy") { @parent_vm.add_child(@vm) }
      @vm.with_relationship_type("genealogy")        { @vm.add_child(@child_vm) }

      [@rp, @parent_vm, @vm, @child_vm].each(&:clear_relationships_cache)
    end

    context "#destroy" do
      before(:each) do
        @vm.destroy
      end

      it "should destroy all relationships" do
        Relationship.where(:resource_type => "Vm", :resource_id => @vm.id).count.should == 0
        Relationship.where(:resource_type => "Vm", :resource_id => @child_vm.id).count.should == 0

        @parent_vm.children.should == []
        @child_vm.parents.should == []
        @rp.children.should == []
      end
    end
  end

  context "#invoke_tasks_local" do
    before(:each) do
      @guid, @server, @zone = EvmSpecHelper.create_guid_miq_server_zone
      @host = FactoryGirl.create(:host)
      @vm = FactoryGirl.create(:vm_vmware, :host => @host)
    end

    it "sets up standard callback for non Power Operations" do
      options = {:task => "create_snapshot", :invoke_by => :task, :ids => [@vm.id]}
      Vm.invoke_tasks_local(options)
      MiqTask.count.should == 1
      task = MiqTask.first
      MiqQueue.count.should == 1
      msg = MiqQueue.first
      msg.miq_callback.should == {:class_name => "MiqTask", :method_name => :queue_callback, :instance_id => task.id, :args => ["Finished"]}
    end

    it "sets up powerops callback for Power Operations" do
      options = {:task => "start", :invoke_by => :task, :ids => [@vm.id]}
      Vm.invoke_tasks_local(options)
      MiqTask.count.should == 1
      task = MiqTask.first
      MiqQueue.count.should == 1
      msg = MiqQueue.first
      msg.miq_callback.should == {:class_name => @vm.class.base_class.name, :method_name => :powerops_callback, :instance_id => @vm.id, :args => [task.id]}

      Vm.stub(:start).and_raise(MiqException::MiqVimBrokerUnavailable)
      msg.deliver
    end

    it "retirement passes in userid" do
      options = {:task => "retire_now", :invoke_by => :task, :ids => [@vm.id], :userid => "Freddy"}
      Vm.invoke_tasks_local(options)
      MiqTask.count.should == 1
      task = MiqTask.first
      MiqQueue.count.should == 1
      msg = MiqQueue.first

      msg.miq_callback.should == {:class_name => "MiqTask", :method_name => :queue_callback,
                                  :instance_id => task.id, :args => ["Finished"]}
      msg.args.should == ["Freddy"]
    end
  end

  context "#start" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
      @host = FactoryGirl.create(:host_vmware)
      @vm = FactoryGirl.create(:vm_vmware,
                               :host      => @host,
                               :miq_group => FactoryGirl.create(:miq_group)
                              )
      FactoryGirl.create(:miq_event_definition, :name => :request_vm_start)
      # admin user is needed to process Events
      User.super_admin || FactoryGirl.create(:user_with_group, :userid => "admin")
    end

    it "policy passes" do
      expect_any_instance_of(ManageIQ::Providers::Vmware::InfraManager::Vm).to receive(:raw_start)

      MiqAeEngine.stub(:deliver => ['ok', 'sucess', MiqAeEngine::MiqAeWorkspaceRuntime.new])
      @vm.start
      status, message, result = MiqQueue.first.deliver
      MiqQueue.first.delivered(status, message, result)
    end

    it "policy prevented" do
      expect_any_instance_of(ManageIQ::Providers::Vmware::InfraManager::Vm).to_not receive(:raw_start)

      event = {:attributes => {"full_data" => {:policy => {:prevented => true}}}}
      MiqAeEngine::MiqAeWorkspaceRuntime.any_instance.stub(:get_obj_from_path).with("/").and_return(:event_stream => event)
      MiqAeEngine.stub(:deliver => ['ok', 'sucess', MiqAeEngine::MiqAeWorkspaceRuntime.new])
      @vm.start
      status, message, _result = MiqQueue.first.deliver
      MiqQueue.first.delivered(status, message, MiqAeEngine::MiqAeWorkspaceRuntime.new)
    end
  end

  it "#save_drift_state" do
    # TODO: Beef up with more data
    vm = FactoryGirl.create(:vm_vmware)
    vm.save_drift_state

    vm.drift_states.size.should == 1
    DriftState.count.should == 1

    vm.drift_states.first.data.should == {
      :class               => "ManageIQ::Providers::Vmware::InfraManager::Vm",
      :id                  => vm.id,
      :location            => vm.location,
      :name                => vm.name,
      :vendor              => "VMware",

      :files               => [],
      :filesystem_drivers  => [],
      :groups              => [],
      :guest_applications  => [],
      :kernel_drivers      => [],
      :linux_initprocesses => [],
      :patches             => [],
      :registry_items      => [],
      :tags                => [],
      :users               => [],
      :win32_services      => [],
    }
  end

  context ".process_tasks" do
    before(:each) do
      @guid, @server, @zone = EvmSpecHelper.create_guid_miq_server_zone
      @host = FactoryGirl.create(:host_vmware, :name => "test_host",    :hostname   => "test_host", :state => 'on')
    end

    it "deletes VM via call to MiqTask#queue_callback and verifies message" do
      @vm1 = FactoryGirl.create(:vm_vmware, :host => @host, :name => "VM-mini1")

      @vm1.class.process_tasks(:task => "destroy", :userid => "system", :ids => [@vm1.id])

      MiqQueue.count.should == 1
      @msg1 = MiqQueue.first
      status, message, result = @msg1.deliver

      @msg1.state.should == "ready"
      @msg1.class_name.should == "ManageIQ::Providers::Vmware::InfraManager::Vm"
      @msg1.args.each do |h|
        h[:task].should == "destroy"
        h[:ids].should == [@vm1.id]
        h[:userid].should == "system"
      end

      @msg1.destroy
      MiqQueue.count.should == 1
      @msg2 = MiqQueue.first
      status, message, result = @msg2.deliver
      MiqTask.any_instance.should_receive(:queue_callback).with("Finished", status, message, result)
      @msg2.delivered(status, message, result)
    end

    it "deletes VM via call to MiqTask#queue_callback and successfully saves object image via YAML.dump" do
      @vm2 = FactoryGirl.create(:vm_vmware, :host => @host, :name => "VM-mini2")
      @vm2.destroy
      -> { YAML.dump(@vm2) }.should_not raise_error
    end
  end
end
