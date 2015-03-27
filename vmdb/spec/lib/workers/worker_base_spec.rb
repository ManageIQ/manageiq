require "spec_helper"

require 'workers/worker_base'

describe WorkerBase do
  context "#check_parent_process" do
    before(:each) do
      _guid, @miq_server, _zone = EvmSpecHelper.create_guid_miq_server_zone

      @worker_guid = MiqUUID.new_guid
      @worker = FactoryGirl.create(:miq_worker, :guid => @worker_guid, :miq_server_id => @miq_server.id)

      WorkerBase.any_instance.stub(:worker_initialization)
      @worker_base = WorkerBase.new(:guid => @worker_guid)
    end

    it "will exit if parent has never heartbeated" do
      @miq_server.update_attribute(:last_heartbeat, nil)
      @worker_base.worker_settings = {:parent_time_threshold => 3.minutes }
      @worker_base.should_receive(:do_exit)
      @worker_base.send(:check_parent_process)
    end

    it "will exit if parent hasn't hearbeated within threshold" do
      @miq_server.update_attribute(:last_heartbeat, 4.minutes.ago.utc)
      @worker_base.worker_settings = {:parent_time_threshold => 3.minutes }
      @worker_base.should_receive(:do_exit)
      @worker_base.send(:check_parent_process)
    end

    it "will NOT exit if parent has hearbeated within threshold" do
      @miq_server.update_attribute(:last_heartbeat, 2.minutes.ago.utc)
      @worker_base.worker_settings = {:parent_time_threshold => 3.minutes }
      @worker_base.should_receive(:do_exit).never
      @worker_base.send(:check_parent_process)
    end

  end
end
