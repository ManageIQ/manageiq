require "spec_helper"

describe MiqAction do
  before(:each) { MiqRegion.seed }

  context "#action_custom_automation" do
    before(:each) do
      @vm   = FactoryGirl.create(:vm_vmware)
      FactoryGirl.create(:miq_action, :name => "custom_automation")
      @action = MiqAction.find_by_name("custom_automation")
      @action.should_not be_nil
      @action.options = {:ae_request => "test_custom_automation"}
      @args = {
        :object_type      => @vm.class.base_class.name,
        :object_id        => @vm.id,
        :attrs            => {:request => "test_custom_automation"},
        :instance_name    => "REQUEST",
        :automate_message => "create"
      }
    end

    it "synchronous" do
      MiqAeEngine.should_receive(:deliver).with(@args).once
      @action.action_custom_automation(@action, @vm, :synchronous => true)
    end

    it "asynchronous" do
      MiqAeEngine.should_receive(:deliver).never

      q_options = {
        :class_name  => 'MiqAeEngine',
        :method_name => 'deliver',
        :args        => [@args],
        :role        => 'automate',
        :zone        => nil,
        :priority    => MiqQueue::HIGH_PRIORITY,
      }
      MiqQueue.should_receive(:put).with(q_options).once
      @action.action_custom_automation(@action, @vm, :synchronous => false)
    end
  end

  it "#action_evm_event" do
    ems = FactoryGirl.create(:ems_vmware)
    host = FactoryGirl.create(:host_vmware)
    vm = FactoryGirl.create(:vm_vmware, :host => host, :ext_management_system => ems)
    action = FactoryGirl.create(:miq_action)
    EmsEvent.any_instance.should_receive(:handle_event).never
    res = action.action_evm_event(action, vm, :policy => MiqPolicy.new)

    res.should be_kind_of EmsEvent
    res.host_id.should == host.id
    res.ems_id.should  == ems.id
  end

  context "#raise_automation_event" do
    before(:each) do
      @vm   = FactoryGirl.create(:vm_vmware)
      FactoryGirl.create(:miq_event, :name => "raise_automation_event")
      FactoryGirl.create(:miq_event, :name => "vm_start")
      FactoryGirl.create(:miq_action, :name => "raise_automation_event")
      @action = MiqAction.find_by_name("raise_automation_event")
      @action.should_not be_nil
      @event = MiqEvent.find_by_name("vm_start")
      @event.should_not be_nil
      @aevent = {
        :vm     => @vm,
        :host   => nil,
        :ems    => nil,
        :policy => @policy,
      }
    end

    it "synchronous" do
      MiqAeEvent.should_receive(:raise_synthetic_event).with(@event.name, @aevent).once
      MiqQueue.should_receive(:put).never
      @action.action_raise_automation_event(@action, @vm, {:vm => @vm, :event => @event, :policy => @policy, :synchronous => true } )
    end

    it "synchronous, not passing vm in inputs hash" do
      MiqAeEvent.should_receive(:raise_synthetic_event).with(@event.name, @aevent).once
      MiqQueue.should_receive(:put).never
      @action.action_raise_automation_event(@action, @vm, {:vm => nil, :event => @event, :policy => @policy, :synchronous => true } )
    end

    it "asynchronous" do
      vm_zone = "vm_zone"
      @vm.stub(:my_zone).and_return(vm_zone)
      MiqAeEvent.should_receive(:raise_synthetic_event).never
      q_options = {
        :class_name  => "MiqAeEvent",
        :method_name => "raise_synthetic_event",
        :args        => [@event.name, @aevent],
        :priority    => MiqQueue::HIGH_PRIORITY,
        :zone        => vm_zone,
        :role        => "automate"
      }
      MiqQueue.should_receive(:put).with(q_options).once
      @action.action_raise_automation_event(@action, @vm, {:vm => @vm, :event => @event, :policy => @policy, :synchronous => false })
    end
  end

  context "#action_ems_refresh" do
    before(:each) do
      FactoryGirl.create(:miq_action, :name => "ems_refresh")
      @action = MiqAction.find_by_name("ems_refresh")
      @action.should_not be_nil
      @zone1 = FactoryGirl.create(:small_environment)
      @vm = @zone1.vms.first
    end

    it "synchronous" do
      EmsRefresh.should_receive(:refresh).with(@vm).once
      EmsRefresh.should_receive(:queue_refresh).never
      @action.action_ems_refresh(@action, @vm, {:vm => @vm, :policy => @policy, :event => @event, :synchronous => true})
    end

    it "asynchronous" do
      EmsRefresh.should_receive(:refresh).never
      EmsRefresh.should_receive(:queue_refresh).with(@vm).once
      @action.action_ems_refresh(@action, @vm, {:vm => @vm, :policy => @policy, :event => @event, :synchronous => false})
    end
  end

  context "#action_vm_retire" do
    before do
      @vm     = FactoryGirl.create(:vm_vmware)
      @event  = FactoryGirl.create(:miq_event, :name => "assigned_company_tag")
      @action = FactoryGirl.create(:miq_action, :name => "vm_retire") 
    end

    it "synchronous" do
      input  = { :synchronous => true }

      Timecop.freeze do
        date   = Time.now.utc - 1.day

        VmOrTemplate.should_receive(:retire) do |vms, options|
          vms.should == [@vm]
          options[:date].should be_same_time_as date
        end
        @action.action_vm_retire(@action, @vm, input)
      end
    end

    it "asynchronous" do
      input = { :synchronous => false }
      zone  = 'Test Zone'
      @vm.stub(:my_zone => zone)

      Timecop.freeze do
        date   = Time.now.utc - 1.day

        @action.action_vm_retire(@action, @vm, input)
        MiqQueue.count.should == 1
        msg = MiqQueue.first
        msg.class_name.should  == @vm.class.name
        msg.method_name.should == 'retire'
        msg.args.should == [[@vm], :date => date]
        msg.zone.should == zone
      end
    end
  end
end
