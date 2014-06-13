require "spec_helper"

require 'workers/worker_base'

describe WorkerBase do
  context "with a worker script and worker row" do
    before(:each) do
      @server_guid = MiqUUID.new_guid
      MiqServer.stub(:my_guid).and_return(@server_guid)
      @zone       = FactoryGirl.create(:zone)
      @miq_server = FactoryGirl.create(:miq_server_master, :zone => @zone, :guid => @server_guid)
      MiqServer.my_server(true)

      @worker_guid = MiqUUID.new_guid
      @worker = FactoryGirl.create(:miq_worker, :guid => @worker_guid, :miq_server_id => @miq_server.id)

      #FIXME: worker scripts need fix the below methods/instance variables to make it easier to test
      WorkerBase.any_instance.stub(:sync_active_roles)
      WorkerBase.any_instance.stub(:sync_config)
      WorkerBase.any_instance.stub(:set_connection_pool_size)

      # All that for this...
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
