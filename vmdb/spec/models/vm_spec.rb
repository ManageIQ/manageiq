require "spec_helper"

describe Vm do
  it "#corresponding_model" do
    Vm.corresponding_model.should == MiqTemplate
    VmVmware.corresponding_model.should == TemplateVmware
    VmRedhat.corresponding_model.should == TemplateRedhat
  end

  it "#corresponding_template_model" do
    Vm.corresponding_template_model.should == MiqTemplate
    VmVmware.corresponding_template_model.should == TemplateVmware
    VmRedhat.corresponding_template_model.should == TemplateRedhat
  end

  context "#template=" do
    before(:each) { @vm = FactoryGirl.create(:vm_vmware) }

    it "false" do
      @vm.update_attribute(:template, false)
      @vm.type.should     == "VmVmware"
      @vm.template.should == false
      @vm.state.should    == "on"
      lambda { @vm.reload }.should_not raise_error
      lambda { TemplateVmware.find(@vm.id) }.should raise_error ActiveRecord::RecordNotFound
    end

    it "true" do
      @vm.update_attribute(:template, true)
      @vm.type.should     == "TemplateVmware"
      @vm.template.should == true
      @vm.state.should    == "never"
      lambda { @vm.reload }.should raise_error ActiveRecord::RecordNotFound
      lambda { TemplateVmware.find(@vm.id) }.should_not raise_error
    end
  end

  it "#validate_remote_console_vmrc_support only suppored on vmware" do
    vm = FactoryGirl.create(:vm_redhat, :vendor => "redhat")
    lambda { vm.validate_remote_console_vmrc_support }.should raise_error MiqException::RemoteConsoleNotSupportedError
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
      options = { :task => "create_snapshot", :invoke_by => :task, :ids => [@vm.id] }
      Vm.invoke_tasks_local(options)
      MiqTask.count.should == 1
      task = MiqTask.first
      MiqQueue.count.should == 1
      msg = MiqQueue.first
      msg.miq_callback.should == {:class_name=>"MiqTask", :method_name=>:queue_callback, :instance_id=>task.id, :args=>["Finished"]}
    end

    it "sets up powerops callback for Power Operations" do
      options = { :task => "start", :invoke_by => :task, :ids => [@vm.id] }
      Vm.invoke_tasks_local(options)
      MiqTask.count.should == 1
      task = MiqTask.first
      MiqQueue.count.should == 1
      msg = MiqQueue.first
      msg.miq_callback.should == {:class_name=>@vm.class.base_class.name, :method_name=>:powerops_callback, :instance_id=>@vm.id, :args=>[task.id]}

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
    before(:each) do
      @guid, @server, @zone = EvmSpecHelper.create_guid_miq_server_zone
      @host = FactoryGirl.create(:host_vmware)
      @vm = FactoryGirl.create(:vm_vmware, :host => @host)
      @task = FactoryGirl.create(:miq_task)
      callback = {:class_name=>@vm.class.base_class.name, :method_name=>:powerops_callback, :instance_id=>@vm.id, :args=>[@task.id]}
      @msg = FactoryGirl.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :handler => @miq_server, :class_name => 'Vm', :instance_id => @vm.id, :method_name => 'start', :miq_callback => callback)
    end

    it "queue message with powerops_callback calls MiqTask#queue_callback when Broker is Available" do
      VmVmware.any_instance.stub(:run_command_via_parent).and_return(true)
      status, message, result = @msg.deliver
      status.should == MiqQueue::STATUS_OK
      MiqTask.any_instance.should_receive(:queue_callback).with("Finished", status, message, result)
      @msg.delivered(status, message, result)
    end

    it "queue message with powerops_callback retries in 1 minute when Broker is NOT Available" do
      VmVmware.any_instance.stub(:run_command_via_parent).and_raise(MiqException::MiqVimBrokerUnavailable)
      status, message, result = @msg.deliver
      status.should == MiqQueue::STATUS_ERROR
      @msg.should_receive(:requeue)
      @msg.delivered(status, message, result)
    end
  end

  it "#save_drift_state" do
    #TODO: Beef up with more data
    vm = FactoryGirl.create(:vm_vmware)
    vm.save_drift_state

    vm.drift_states.size.should == 1
    DriftState.count.should == 1

    vm.drift_states.first.data.should == {
      :class               => "VmVmware",
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

      @vm1.class.process_tasks(:task => "destroy", :userid=>"system", :ids => [@vm1.id])

      MiqQueue.count.should == 1
      @msg1 = MiqQueue.first
      status, message, result = @msg1.deliver

      @msg1.state.should      == "ready"
      @msg1.class_name.should == "VmVmware"
      @msg1.args.each do |h|
        h[:task].should   == "destroy"
        h[:ids].should    == [@vm1.id]
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
        lambda { YAML.dump(@vm2) }.should_not raise_error
    end
  end

end
