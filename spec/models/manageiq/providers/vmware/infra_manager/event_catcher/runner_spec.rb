require "spec_helper"

describe ManageIQ::Providers::Vmware::InfraManager::EventCatcher::Runner do
  let(:ems)      { FactoryGirl.create(:ems_vmware, :hostname => "hostname") }
  let(:catcher)  { ManageIQ::Providers::Vmware::InfraManager::EventCatcher::Runner.new(:ems_id => ems.id) }
  let(:settings) { {:flooding_monitor_enabled => false} }

  before do
    allow_any_instance_of(ManageIQ::Providers::Vmware::InfraManager).to receive(:authentication_check).and_return([true, ""])
    allow_any_instance_of(MiqWorker::Runner).to receive(:worker_initialization)
    allow_any_instance_of(MiqWorker::Runner).to receive(:worker_settings).and_return(settings)
  end

  describe "#event_dedup_key" do
    let(:test_event1) do
      {
        "key"                  => "9418",
        "chainId"              => "9418",
        "createdTime"          => "2015-12-10T17:11:26.485713Z",
        "userName"             => "root",
        "datacenter"           => {"name" => "VC0DC0",       "datacenter"      => "datacenter-2"},
        "computeResource"      => {"name" => "VC0DC0_C7",    "computeResource" => "domain-c842"},
        "host"                 => {"name" => "VC0DC0_C7_H2", "host"            => "host-849"},
        "fullFormattedMessage" => "Task: Power On virtual machine",
        "eventType"            => "TaskEvent",
        "vm"                   =>
          {
            "name" => "VC0DC0_C7_RP4_VM12",
            "vm"   => "vm-952",
            "path" => "[GlobalDS_0] VC0DC0_C7_RP4_VM12/VC0DC0_C7_RP4_VM12.vmx"
          },
        "info"                =>
          {
            "key"           => "task-575",
            "task"          => "task-575",
            "name"          => "PowerOnVM_Task",
            "descriptionId" => "VirtualMachine.powerOn",
            "entity"        => "vm-952",
            "entityName"    => "VC0DC0_C7_RP4_VM12",
            "state"         => "queued",
            "cancelled"     => "false",
            "cancelable"    => "false",
            "reason"        => {"userName" => "root"},
            "queueTime"     => "2015-12-10T17:11:26.479554Z",
            "eventChainId"  => "9418"
          }
      }
    end

    let(:test_event2) do
      test_event1.tap do |event|
        event.merge(
          "key"         => "9419",
          "chainId"     => "9419",
          "createdTime" => "2015-12-10T17:12:26.485713Z",
        )
        event["info"].merge(
          "key"          => "task-576",
          "task"         => "task-576",
          "queueTime"    => "2015-12-10T17:11:27.479554Z",
          "eventChainId" => "9419"
        )
      end
    end

    let(:test_event3) do
      test_event1.tap do |event|
        event["userName"] = "admin"
      end
    end

    context "events differ only from neglected attributes" do
      it "creates the same dedup key" do
        expect(catcher.event_dedup_key(test_event1)).to eq(catcher.event_dedup_key(test_event2))
      end
    end

    context "events differ from non-neglected attributes" do
      it "creates different dedup keys" do
        expect(catcher.event_dedup_key(test_event1)).not_to eq(catcher.event_dedup_key(test_event3))
      end
    end
  end

  describe "#queue_event" do
    before do
      ManageIQ::Providers::Vmware::InfraManager::EventCatcher.send(:remove_const, :Runner)
      load 'app/models/manageiq/providers/vmware/infra_manager/event_catcher/runner.rb'
    end

    context "event flooding monitor is enabled" do
      let(:settings) do
        {
          :flooding_monitor_enabled   => true,
          :flooding_monitor_threshold => 0,
          :flooding_monitor_window    => 1,
          :flooding_monitor_slot_size => 0.1,
          :flooded_log_count          => 1
        }
      end

      it "does not place the flooded event to the queue" do
        expect(EmsEvent).not_to receive(:add_queue)
        catcher.queue_event(:name => "some event")
      end
    end

    context "event flooding monitor is disabled" do
      it "places every event to the queue" do
        expect(EmsEvent).to receive(:add_queue)
        catcher.queue_event(:name => "some event")
      end
    end
  end
end
