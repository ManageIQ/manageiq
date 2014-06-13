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

  context "with relationships of multiple types" do
    before(:each) do
      @rp        = FactoryGirl.create(:resource_pool, :name => "RP")
      @parent_vm = FactoryGirl.create(:vm_vmware, :name => "Parent VM")
      @vm        = FactoryGirl.create(:vm_vmware, :name => "VM")
      @child_vm  = FactoryGirl.create(:vm_vmware, :name => "Child VM")

      @rp.with_relationship_type("ems_metadata")     { @rp.add_child(@vm) }
      @parent_vm.with_relationship_type("genealogy") { @parent_vm.add_child(@vm) }
      @vm.with_relationship_type("genealogy")        { @vm.add_child(@child_vm) }

      [@rp, @parent_vm, @vm, @child_vm].each { |o| o.clear_relationships_cache }
    end

    context "#destroy" do
      before(:each) do
        @vm.destroy
      end

      it "should destroy all relationships" do
        Relationship.count(:conditions => {:resource_type => "Vm", :resource_id => @vm.id}).should == 0
        Relationship.count(:conditions => {:resource_type => "Vm", :resource_id => @child_vm.id}).should == 0

        @parent_vm.children.should == []
        @child_vm.parents.should == []
        @rp.children.should == []
      end
    end
  end

  context "with a small env" do
    before(:each) do
      @zone1 = FactoryGirl.create(:small_environment)
      MiqServer.stub(:my_server).and_return(@zone1.miq_servers.first)
    end

    it "will not have an active VDI session" do
      vm = @zone1.vms.first
      vm.has_active_vdi_session.should be_false
    end

    context "with a VDI Desktop relationship" do
      before(:each) do
        @vm = @zone1.vms.first
        FactoryGirl.create(:vdi_desktop, :vm_or_template_id => @vm.id)
      end

      it "should not have an active session" do
        @vm.has_active_vdi_session.should be_false
      end

      context "with a VDI session" do
        before(:each) do
          @vdi_session = FactoryGirl.create(:vdi_session, :vdi_desktop_id => @vm.vdi_desktop.id, :state => 'Disconnected')
        end

        it "should detect an active session" do
          @vm.vdi_desktop.vdi_sessions.first.state = 'Disconnected'
          @vm.has_active_vdi_session.should be_false

          @vm.vdi_desktop.vdi_sessions.first.state = 'Connected'
          @vm.has_active_vdi_session.should be_true

          @vm.vdi_desktop.vdi_sessions.first.state = 'Connecting'
          @vm.has_active_vdi_session.should be_false

          @vm.vdi_desktop.vdi_sessions.first.state = 'ConsoleLoggedIn'
          @vm.has_active_vdi_session.should be_true
        end
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
