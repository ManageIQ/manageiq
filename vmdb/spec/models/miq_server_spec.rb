require "spec_helper"

describe MiqServer do
  GUID_FILE = File.join(Rails.root, "GUID")
  def read_guid
    (File.open(GUID_FILE, 'r') {|f| f.read }).chomp if File.exist?(GUID_FILE)
  end

  def write_guid(number)
    File.open(GUID_FILE, 'w') {|f| f.write(number) } if File.exist?(GUID_FILE)
  end

  context "with no guid file" do
    before(:each) do
      MiqServer.my_guid_cache = nil
      @guid_existed_before = File.exist?(GUID_FILE)
      if @guid_existed_before
        @orig_guid = self.read_guid
        File.delete(GUID_FILE)
      end
    end

    after(:each) do
      if File.exist?(GUID_FILE) && !@guid_existed_before
        File.delete(GUID_FILE)
      else
        self.write_guid(@orig_guid) unless @orig_guid.nil?
      end
    end

    it "should generate a new GUID file" do
      File.exist?(GUID_FILE).should be_false
      guid = MiqServer.my_guid
      File.exist?(GUID_FILE).should be_true
      File.read(GUID_FILE).strip.should == guid
    end

    it "should not generate a new GUID file if new_guid blows up" do
      # Test for case 10942
      File.exist?(GUID_FILE).should be_false
      MiqUUID.should_receive(:new_guid).and_raise(StandardError)
      lambda { MiqServer.my_guid }.should raise_error(StandardError)
      File.exist?(GUID_FILE).should be_false
    end
  end

  context "instance" do
    before do
      @guid, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone
      MiqServer.my_server(true)
    end

    it "should have proper guid" do
      @miq_server.guid.should == @guid
    end

    it "should have default zone" do
      @miq_server.zone.name.should == @zone.name
    end

    it "shutdown will raise an event and quiesce" do
       MiqEvent.should_receive(:raise_evm_event)
       @miq_server.should_receive(:quiesce)
       @miq_server.shutdown
    end

    it "sync stop will do nothing if stopped" do
      @miq_server.update_attributes(:status => 'stopped')
      @miq_server.should_receive(:wait_for_stopped).never
      @miq_server.stop(true)
      MiqQueue.exists?(:method_name => 'shutdown_and_exit', :queue_name => :miq_server, :server_guid => @miq_server.guid).should_not be_true
    end

    it "async stop will do nothing if stopped" do
      @miq_server.update_attributes(:status => 'stopped')
      @miq_server.should_receive(:wait_for_stopped).never
      @miq_server.stop(false)
      MiqQueue.exists?(:method_name => 'shutdown_and_exit', :queue_name => :miq_server, :server_guid => @miq_server.guid).should_not be_true
    end

    it "sync stop will do nothing if killed" do
      @miq_server.update_attributes(:status => 'killed')
      @miq_server.reload
      @miq_server.should_receive(:wait_for_stopped).never
      @miq_server.stop(true)
      MiqQueue.exists?(:method_name => 'shutdown_and_exit', :queue_name => :miq_server, :server_guid => @miq_server.guid).should_not be_true
    end

    it "sync stop will queue shutdown_and_exit and wait_for_stopped" do
      @miq_server.update_attributes(:status => 'started')
      @miq_server.should_receive(:wait_for_stopped)
      @miq_server.stop(true)
      MiqQueue.exists?(:method_name => 'shutdown_and_exit', :queue_name => :miq_server, :server_guid => @miq_server.guid).should be_true
    end

    it "async stop will queue shutdown_and_exit and return" do
      @miq_server.update_attributes(:status => 'started')
      @miq_server.should_receive(:wait_for_stopped).never
      @miq_server.stop(false)
      MiqQueue.exists?(:method_name => 'shutdown_and_exit', :queue_name => :miq_server, :server_guid => @miq_server.guid).should be_true
    end

    it "async stop will not update existing exit message and return" do
      @miq_server.update_attributes(:status => 'started')
      @miq_server.should_receive(:wait_for_stopped).never
      @miq_server.stop(false)
    end

    context "#is_recently_active?" do
      it "should return false when last_heartbeat is nil" do
        @miq_server.last_heartbeat = nil
        @miq_server.is_recently_active?.should be_false
      end

      it "should return false when last_heartbeat is at least 10.minutes ago" do
        @miq_server.last_heartbeat = 10.minutes.ago.utc
        @miq_server.is_recently_active?.should be_false
      end

      it "should return true when last_heartbeat is less than 10.minutes ago" do
        @miq_server.last_heartbeat = 500.seconds.ago.utc
        @miq_server.is_recently_active?.should be_true
      end
    end

    context "#ntp_reload_queue" do
      before(:each) do
        MiqQueue.destroy_all
        @cond = {:method_name => 'ntp_reload', :class_name => 'MiqServer', :instance_id => @miq_server.id, :server_guid => @miq_server.guid, :zone => @miq_server.zone.name }
        @miq_server.ntp_reload_queue
        @message = MiqQueue.where(@cond).first
      end

      it "will queue up a message" do
        @message.should_not be_nil
      end

      it "message will be high priority" do
        @message.priority.should == MiqQueue::HIGH_PRIORITY
      end

      it "will not requeue if one exists" do
        MiqQueue.count(:conditions => @cond).should == 1
        @miq_server.ntp_reload_queue
        MiqQueue.count(:conditions => @cond).should == 1
      end
    end

    context "#ntp_reload" do
      require 'miq-ntp'
      let(:config)     { @miq_server.get_config("vmdb") }
      let(:server_ntp) { {:server => ["server.pool.com"]} }
      let(:zone_ntp)   { {:server => ["zone.pool.com"]} }

      it "syncs with server settings with zone and server configured" do
        @zone.update_attribute(:settings, :ntp => zone_ntp)
        config.config = {:ntp => server_ntp}
        config.save

        MiqNtp.should_receive(:sync_settings).with(server_ntp)
        @miq_server.ntp_reload
      end

      it "syncs with zone settings if server not configured" do
        @zone.update_attribute(:settings, :ntp => zone_ntp)
        config.config = {}
        config.save

        MiqNtp.should_receive(:sync_settings).with(zone_ntp)
        @miq_server.ntp_reload
      end

      it "syncs with default zone settings if server and zone not configured" do
        @zone.update_attribute(:settings, {})
        config.config = {}
        config.save

        MiqNtp.should_receive(:sync_settings).with(Zone::DEFAULT_NTP_SERVERS)
        @miq_server.ntp_reload
      end
    end

    context "enqueueing restart of apache" do
      before(:each) do
        @cond = {:method_name => 'restart_apache', :queue_name => "miq_server", :class_name => 'MiqServer', :instance_id => @miq_server.id, :server_guid => @miq_server.guid, :zone => @miq_server.zone.name}
        @miq_server.queue_restart_apache
      end

      it "will queue only one restart_apache" do
        @miq_server.queue_restart_apache
        MiqQueue.count(:conditions => @cond).should == 1
      end

      it "delivering will restart apache" do
        MiqApache::Control.should_receive(:restart).with(false)
        @miq_server.process_miq_queue
      end
    end

    context "with a worker" do
      before(:each) do
        @worker = FactoryGirl.create(:miq_worker, :miq_server_id => @miq_server.id, :pid => Process.pid)
        @miq_server.stub(:validate_worker).and_return(true)
        @miq_server.setup_drb_variables
        @miq_server.worker_add(@worker.pid)
      end

      it "quiesce will update status to quiesce, deactivate_roles, quiesce workers, clean active messages, and set status to stopped" do
        @miq_server.should_receive(:status=).with('quiesce')
        @miq_server.should_receive(:deactivate_roles)
        @miq_server.should_receive(:quiesce_workers_loop)
        MiqWorker.any_instance.should_receive(:clean_active_messages)
        @miq_server.should_receive(:status=).with('stopped')
        @miq_server.quiesce
      end

      it "quiesce_workers_loop will initiate shutdown of workers" do
        @miq_server.should_receive(:stop_worker)
        @miq_server.instance_variable_set(:@worker_monitor_settings, {:quiesce_loop_timeout => 15.minutes})
        @miq_server.should_receive(:workers_quiesced?).and_return(true)
        @miq_server.quiesce_workers_loop
      end

      it "quiesce_workers do mini-monitor_workers loop" do
        @miq_server.should_receive(:heartbeat)
        @miq_server.should_receive(:quiesce_workers_loop_timeout?).never
        @miq_server.should_receive(:kill_timed_out_worker_quiesce).never
        MiqWorker.any_instance.stub(:is_stopped?).and_return(true, false)
        @miq_server.workers_quiesced?
      end

      it "quiesce_workers_loop_timeout? will return true if timeout reached" do
        @miq_server.instance_variable_set(:@quiesce_started_on, Time.now.utc)
        @miq_server.instance_variable_set(:@quiesce_loop_timeout, 10.minutes)
        @miq_server.quiesce_workers_loop_timeout?.should_not be_true

        Timecop.travel 10.minutes do
          @miq_server.quiesce_workers_loop_timeout?.should be_true
        end
      end

      it "quiesce_workers_loop_timeout? will return false if timeout is not reached" do
        @miq_server.instance_variable_set(:@quiesce_started_on, Time.now.utc)
        @miq_server.instance_variable_set(:@quiesce_loop_timeout, 10.minutes)
        MiqWorker.any_instance.should_receive(:kill).never
        @miq_server.quiesce_workers_loop_timeout?.should_not be_true
      end

      it "will not kill workers if their quiesce timeout is not reached" do
        @miq_server.instance_variable_set(:@quiesce_started_on, Time.now.utc)
        MiqWorker.any_instance.stub(:quiesce_time_allowance).and_return(10.minutes)
        MiqWorker.any_instance.should_receive(:kill).never
        @miq_server.kill_timed_out_worker_quiesce
      end

      it "will kill workers if their quiesce timeout is reached" do
        @miq_server.instance_variable_set(:@quiesce_started_on, Time.now.utc)
        MiqWorker.any_instance.stub(:quiesce_time_allowance).and_return(10.minutes)
        @miq_server.kill_timed_out_worker_quiesce

        Timecop.travel 10.minutes do
          MiqWorker.any_instance.should_receive(:kill).once
          @miq_server.kill_timed_out_worker_quiesce
        end
      end

      context "with an active messsage and a second server" do
        before(:each) do
          @msg = FactoryGirl.create(:miq_queue, :state => 'dequeue')
          @guid2 = MiqUUID.new_guid
          @miq_server2 = FactoryGirl.create(:miq_server_master, :zone => @zone, :guid => @guid2)
        end

        it "will validate the 'started' first server's active message when called on it" do
          @msg.handler = @miq_server.reload
          @msg.save
          MiqQueue.any_instance.should_receive(:check_for_timeout)
          @miq_server.validate_active_messages
        end

        it "will validate the 'not responding' first server's active message when called on it" do
          @miq_server.update_attribute(:status, 'not responding')
          @msg.handler = @miq_server.reload
          @msg.save
          MiqQueue.any_instance.should_receive(:check_for_timeout)
          @miq_server.validate_active_messages
        end

        it "will validate the 'not resonding' second server's active message when called on first server" do
          @miq_server2.update_attribute(:status, 'not responding')
          @msg.handler = @miq_server2
          @msg.save
          MiqQueue.any_instance.should_receive(:check_for_timeout)
          @miq_server.validate_active_messages
        end

        it "will NOT validate the 'started' second server's active message when called on first server" do
          @miq_server2.update_attribute(:status, 'started')
          @msg.handler = @miq_server2
          @msg.save
          MiqQueue.any_instance.should_receive(:check_for_timeout).never
          @miq_server.validate_active_messages
        end

        it "will validate a worker's active message when called on the worker's server" do
          @msg.handler = @worker
          @msg.save
          MiqQueue.any_instance.should_receive(:check_for_timeout)
          @miq_server.validate_active_messages
        end

        it "will not validate a worker's active message when called on the worker's server if already processed" do
          @msg.handler = @worker
          @msg.save
          MiqQueue.any_instance.should_receive(:check_for_timeout).never
          @miq_server.validate_active_messages([@worker.id])
        end
      end
    end

    context "with server roles" do
      before(:each) do
        @server_roles = []
        [
          ['event',                  1],
          ['ems_metrics_coordinator', 1],
          ['ems_operations',         0]
        ].each { |r, max| @server_roles << FactoryGirl.create(:server_role, :name => r, :max_concurrent => max) }

        @miq_server.role    = @server_roles.collect { |r| r.name }.join(',')

      end

      it "should have all server roles" do
        @miq_server.server_roles.should match_array(@server_roles)
      end

      context "activating All roles" do
        before(:each) do
          @miq_server.activate_all_roles
        end

        it "should have activated All roles" do
          @miq_server.active_roles.should match_array(@server_roles)
        end
      end

      context "activating Event role" do
        before(:each) do
          @miq_server.activate_roles("event")
        end

        it "should have activated Event role" do
          @miq_server.active_role_names.include?("event").should be_true
        end
      end
    end
  end

  describe "#active?" do
    context "Active status returns true" do
      ["starting", "started"].each do |status|
        it status do
          expect(described_class.new(:status => status).active?).to be_true
        end
      end
    end

    it "Inactive status returns false" do
      expect(described_class.new(:status => "stopped").active?).to be_false
    end
  end
end
