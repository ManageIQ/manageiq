describe MiqServer do
  context ".seed" do
    before do
      MiqRegion.seed
      Zone.seed
    end

    include_examples ".seed called multiple times"
  end

  context "#hostname" do
    it("with a valid hostname")    { expect(MiqServer.new(:hostname => "test").hostname).to eq("test") }
    it("with a valid fqdn")        { expect(MiqServer.new(:hostname => "test.example.com").hostname).to eq("test.example.com") }
    it("with an invalid hostname") { expect(MiqServer.new(:hostname => "test_host").hostname).to be_nil }
    it("without a hostname")       { expect(MiqServer.new.hostname).to be_nil }
  end

  context ".my_guid" do
    let(:guid_file) { Rails.root.join("GUID") }

    it "should return the GUID from the file" do
      MiqServer.my_guid_cache = nil
      expect(File).to receive(:exist?).with(guid_file).and_return(true)
      expect(File).to receive(:read).with(guid_file).and_return("an-existing-guid\n\n")
      expect(MiqServer.my_guid).to eq("an-existing-guid")
    end

    it "should generate a new GUID and write it out when there is no GUID file" do
      test_guid = SecureRandom.uuid
      expect(SecureRandom).to receive(:uuid).and_return(test_guid)

      Tempfile.create do |tempfile|
        stub_const("MiqServer::GUID_FILE", tempfile.path)
        MiqServer.my_guid_cache = nil
        expect(MiqServer.my_guid).to eq(test_guid)
        expect(File.read(tempfile)).to eq(test_guid)
      end
    end

    it "should not generate a new GUID file if new_guid blows up" do # Test for case 10942
      MiqServer.my_guid_cache = nil
      expect(SecureRandom).to receive(:uuid).and_raise(StandardError)
      expect(File).to receive(:exist?).with(guid_file).and_return(false)
      expect(File).not_to receive(:write)
      expect { MiqServer.my_guid }.to raise_error(StandardError)
    end
  end

  context "instance" do
    before do
      @guid, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone
    end

    describe "#monitor_myself" do
      it "does not exit with nil memory_usage" do
        @miq_server.update(:memory_usage => nil)
        expect(@miq_server).to receive(:exit).never
        @miq_server.monitor_myself
        expect(Notification.count).to eq(0)
      end

      it "creates a notification and exits with memory usage > limit" do
        NotificationType.seed
        @miq_server.update(:memory_usage => 3.gigabytes)
        expect(@miq_server).to receive(:exit).once
        @miq_server.monitor_myself
        expect(Notification.count).to eq(1)
      end

      it "does not exit with memory_usage < limit" do
        @miq_server.update(:memory_usage => 1.gigabyte)
        expect(@miq_server).to receive(:exit).never
        @miq_server.monitor_myself
        expect(Notification.count).to eq(0)
      end
    end

    describe "#monitor_loop" do
      it "calls shutdown_and_exit if SIGTERM is raised" do
        expect(@miq_server).to receive(:monitor).and_raise(SignalException, "SIGTERM")
        expect(@miq_server).to receive(:shutdown_and_exit)

        @miq_server.monitor_loop
      end

      it "kills the server and exits if SIGINT is raised" do
        expect(@miq_server).to receive(:monitor).and_raise(Interrupt)
        expect(MiqServer).to receive(:kill)
        expect(@miq_server).to receive(:exit).with(1)

        @miq_server.monitor_loop
      end
    end

    it "should have proper guid" do
      expect(@miq_server.guid).to eq(@guid)
    end

    it "should have default zone" do
      expect(@miq_server.zone.name).to eq(@zone.name)
    end

    it "cannot assign to maintenance zone" do
      MiqRegion.seed
      Zone.seed

      @miq_server.zone = Zone.maintenance_zone
      expect(@miq_server.save).to eq(false)
      expect(@miq_server.errors.messages[:zone]).to be_present
    end

    it "shutdown will raise an event and quiesce" do
      expect(MiqEvent).to receive(:raise_evm_event)
      expect(@miq_server).to receive(:quiesce)
      @miq_server.shutdown
    end

    it "sync stop will do nothing if stopped" do
      @miq_server.update(:status => 'stopped')
      expect(@miq_server).to receive(:wait_for_stopped).never
      @miq_server.stop(true)
      expect(MiqQueue.exists?(:method_name => 'shutdown_and_exit', :queue_name => :miq_server, :server_guid => @miq_server.guid)).not_to be_truthy
    end

    it "async stop will do nothing if stopped" do
      @miq_server.update(:status => 'stopped')
      expect(@miq_server).to receive(:wait_for_stopped).never
      @miq_server.stop(false)
      expect(MiqQueue.exists?(:method_name => 'shutdown_and_exit', :queue_name => :miq_server, :server_guid => @miq_server.guid)).not_to be_truthy
    end

    it "sync stop will do nothing if killed" do
      @miq_server.update(:status => 'killed')
      @miq_server.reload
      expect(@miq_server).to receive(:wait_for_stopped).never
      @miq_server.stop(true)
      expect(MiqQueue.exists?(:method_name => 'shutdown_and_exit', :queue_name => :miq_server, :server_guid => @miq_server.guid)).not_to be_truthy
    end

    it "sync stop will queue shutdown_and_exit and wait_for_stopped" do
      @miq_server.update(:status => 'started')
      expect(@miq_server).to receive(:wait_for_stopped)
      @miq_server.stop(true)
      expect(MiqQueue.exists?(:method_name => 'shutdown_and_exit', :queue_name => :miq_server, :server_guid => @miq_server.guid)).to be_truthy
    end

    it "async stop will queue shutdown_and_exit and return" do
      @miq_server.update(:status => 'started')
      expect(@miq_server).to receive(:wait_for_stopped).never
      @miq_server.stop(false)
      expect(MiqQueue.exists?(:method_name => 'shutdown_and_exit', :queue_name => :miq_server, :server_guid => @miq_server.guid)).to be_truthy
    end

    it "async stop will not update existing exit message and return" do
      @miq_server.update(:status => 'started')
      expect(@miq_server).to receive(:wait_for_stopped).never
      @miq_server.stop(false)
    end

    context "#is_recently_active?" do
      it "should return false when last_heartbeat is nil" do
        @miq_server.last_heartbeat = nil
        expect(@miq_server.is_recently_active?).to be_falsey
      end

      it "should return false when last_heartbeat is at least 10.minutes ago" do
        @miq_server.last_heartbeat = 10.minutes.ago.utc
        expect(@miq_server.is_recently_active?).to be_falsey
      end

      it "should return true when last_heartbeat is less than 10.minutes ago" do
        @miq_server.last_heartbeat = 500.seconds.ago.utc
        expect(@miq_server.is_recently_active?).to be_truthy
      end
    end

    context "validate_is_deleteable before destroying" do
      it "prevents deleting the current server" do
        allow(@miq_server).to receive(:is_local?).and_return(true)
        @miq_server.destroy

        expect(@miq_server.errors.full_messages.first).to match(/current/)
      end

      it "prevents deleting recently active server" do
        allow(@miq_server).to receive(:is_local?).and_return(false)
        @miq_server.last_heartbeat = 2.minutes.ago.utc
        @miq_server.destroy

        expect(@miq_server.errors.full_messages.first).to match(/recently/)
      end
    end

    context "#ntp_reload_queue" do
      let(:queue_cond) { {:method_name => 'ntp_reload', :class_name => 'MiqServer', :instance_id => @miq_server.id, :server_guid => @miq_server.guid, :zone => @miq_server.zone.name} }
      let(:message)    { MiqQueue.where(queue_cond).first }

      before { MiqQueue.destroy_all }

      context "when on an appliance" do
        before do
          allow(MiqEnvironment::Command).to receive(:is_appliance?).and_return(true)
          @miq_server.ntp_reload_queue
        end

        it "will queue up a message with high priority" do
          expect(MiqQueue.where(queue_cond)).not_to be_nil
        end
      end

      context "when not on an appliance" do
        before do
          allow(MiqEnvironment::Command).to receive(:is_appliance?).and_return(false)
          @miq_server.ntp_reload_queue
        end

        it "will not queue up a message" do
          expect(message).to be_nil
        end
      end
    end

    context "#ntp_reload" do
      let(:server_ntp) { {:server => ["server.pool.com"]} }
      let(:zone_ntp)   { {:server => ["zone.pool.com"]} }
      let(:chrony)     { double }

      context "when on an appliance" do
        before do
          allow(MiqEnvironment::Command).to receive(:is_appliance?).and_return(true)
        end

        it "doesn't sync the settings when running in a container" do
          allow(MiqEnvironment::Command).to receive(:is_container?).and_return(true)

          @zone.update_attribute(:settings, :ntp => zone_ntp)
          stub_settings(:ntp => server_ntp)

          expect(LinuxAdmin::Chrony).not_to receive(:new)
          @miq_server.ntp_reload
        end

        it "syncs the settings" do
          expect(LinuxAdmin::Chrony).to receive(:new).and_return(chrony)
          expect(chrony).to receive(:clear_servers)
          expect(chrony).to receive(:add_servers).with("0.pool.ntp.org", "1.pool.ntp.org", "2.pool.ntp.org")
          @miq_server.ntp_reload
        end

        it "only changes the config file if there are changes" do
          expect(@miq_server).to receive(:apply_ntp_server_settings).once

          @miq_server.ntp_reload
          @miq_server.ntp_reload
        end
      end

      context "when not on an appliance" do
        before do
          allow(MiqEnvironment::Command).to receive(:is_appliance?).and_return(false)
        end

        it "does not apply NTP settings" do
          expect(LinuxAdmin::Chrony).to_not receive(:new)
          expect(chrony).to_not receive(:clear_servers)
          expect(chrony).to_not receive(:add_servers)
          @miq_server.ntp_reload
        end
      end
    end

    context "with a worker" do
      before do
        @worker = FactoryBot.create(:miq_worker, :miq_server_id => @miq_server.id, :pid => Process.pid)
        allow(@miq_server).to receive(:validate_worker).and_return(true)
        @miq_server.setup_drb_variables
        @miq_server.worker_add(@worker.pid)
      end

      it "quiesce will update status to quiesce, deactivate_roles, quiesce workers, clean active messages, and set status to stopped" do
        expect(@miq_server).to receive(:status=).with('quiesce')
        expect(@miq_server).to receive(:deactivate_roles)
        expect(@miq_server).to receive(:quiesce_workers_loop)
        expect_any_instance_of(MiqWorker).to receive(:clean_active_messages)
        expect(@miq_server).to receive(:status=).with('stopped')
        @miq_server.quiesce
      end

      it "quiesce_workers_loop will initiate shutdown of workers" do
        expect(@miq_server).to receive(:stop_worker)
        @miq_server.instance_variable_set(:@worker_monitor_settings, :quiesce_loop_timeout => 15.minutes)
        expect(@miq_server).to receive(:workers_quiesced?).and_return(true)
        @miq_server.quiesce_workers_loop
      end

      it "quiesce_workers do mini-monitor_workers loop" do
        expect(@miq_server).to receive(:heartbeat)
        expect(@miq_server).to receive(:quiesce_workers_loop_timeout?).never
        allow_any_instance_of(MiqWorker).to receive(:is_stopped?).and_return(true, false)
        @miq_server.workers_quiesced?
      end

      it "quiesce_workers_loop_timeout? will return true if timeout reached" do
        @miq_server.instance_variable_set(:@quiesce_started_on, Time.now.utc)
        @miq_server.instance_variable_set(:@quiesce_loop_timeout, 10.minutes)
        expect(@miq_server.quiesce_workers_loop_timeout?).not_to be_truthy

        Timecop.travel 10.minutes do
          expect(@miq_server.quiesce_workers_loop_timeout?).to be_truthy
        end
      end

      it "quiesce_workers_loop_timeout? will return false if timeout is not reached" do
        @miq_server.instance_variable_set(:@quiesce_started_on, Time.now.utc)
        @miq_server.instance_variable_set(:@quiesce_loop_timeout, 10.minutes)
        expect_any_instance_of(MiqWorker).to receive(:kill).never
        expect(@miq_server.quiesce_workers_loop_timeout?).not_to be_truthy
      end

      context "with an active messsage and a second server" do
        before do
          @msg = FactoryBot.create(:miq_queue, :state => 'dequeue')
          @miq_server2 = FactoryBot.create(:miq_server, :is_master => true, :zone => @zone)
        end

        it "will validate the 'started' first server's active message when called on it" do
          @msg.handler = @miq_server.reload
          @msg.save
          expect_any_instance_of(MiqQueue).to receive(:check_for_timeout)
          @miq_server.validate_active_messages
        end

        it "will validate the 'not responding' first server's active message when called on it" do
          @miq_server.update_attribute(:status, 'not responding')
          @msg.handler = @miq_server.reload
          @msg.save
          expect_any_instance_of(MiqQueue).to receive(:check_for_timeout)
          @miq_server.validate_active_messages
        end

        it "will validate the 'not resonding' second server's active message when called on first server" do
          @miq_server2.update_attribute(:status, 'not responding')
          @msg.handler = @miq_server2
          @msg.save
          expect_any_instance_of(MiqQueue).to receive(:check_for_timeout)
          @miq_server.validate_active_messages
        end

        it "will NOT validate the 'started' second server's active message when called on first server" do
          @miq_server2.update_attribute(:status, 'started')
          @msg.handler = @miq_server2
          @msg.save
          expect_any_instance_of(MiqQueue).to receive(:check_for_timeout).never
          @miq_server.validate_active_messages
        end

        it "will validate a worker's active message when called on the worker's server" do
          @msg.handler = @worker
          @msg.save
          expect_any_instance_of(MiqQueue).to receive(:check_for_timeout)
          @miq_server.validate_active_messages
        end

        it "will not validate a worker's active message when called on the worker's server if already processed" do
          @msg.handler = @worker
          @msg.save
          expect_any_instance_of(MiqQueue).to receive(:check_for_timeout).never
          @miq_server.validate_active_messages([@worker.id])
        end
      end

      context "#server_timezone" do
        it "utc with no system default" do
          stub_settings(:server => {:timezone => nil})
          expect(@miq_server.server_timezone).to eq("UTC")
        end

        it "uses system default" do
          stub_settings(:server => {:timezone => "Eastern Time (US & Canada)"})
          expect(@miq_server.server_timezone).to eq("Eastern Time (US & Canada)")
        end
      end
    end

    context "with server roles" do
      before do
        @server_roles = []
        [
          ['event',                  1],
          ['ems_metrics_coordinator', 1],
          ['ems_operations',         0]
        ].each { |r, max| @server_roles << FactoryBot.create(:server_role, :name => r, :max_concurrent => max) }

        @miq_server.role = @server_roles.collect(&:name).join(',')
      end

      it "should have all server roles" do
        expect(@miq_server.server_roles).to match_array(@server_roles)
      end

      context "activating All roles" do
        before do
          @miq_server.activate_all_roles
        end

        it "should have activated All roles" do
          expect(@miq_server.active_roles).to match_array(@server_roles)
        end
      end

      context "activating Event role" do
        before do
          @miq_server.activate_roles("event")
        end

        it "should have activated Event role" do
          expect(@miq_server.active_role_names.include?("event")).to be_truthy
        end
      end
    end

    context "after_destroy callback" do
      let(:remote_server) { EvmSpecHelper.remote_miq_server }

      describe "#destroy_linked_events_queue" do
        it "queue request to destroy events linked to this server" do
          remote_server.destroy_linked_events_queue
          expect(MiqQueue.find_by(:class_name => 'MiqServer').method_name).to eq 'destroy_linked_events'
        end
      end

      describe ".destroy_linked_events" do
        it "destroys all events associated with destroyed server" do
          FactoryBot.create(:miq_event, :event_type => "Local TestEvent", :target => @miq_server)
          FactoryBot.create(:miq_event, :event_type => "Remote TestEvent 1", :target => remote_server)
          FactoryBot.create(:miq_event, :event_type => "Remote TestEvent 1", :target => remote_server)

          expect(MiqEvent.count).to eq 3

          allow(remote_server).to receive(:is_deleteable?).and_return(true)
          described_class.destroy_linked_events(remote_server.id)
          expect(MiqEvent.count).to eq 1
        end
      end
    end
  end

  it "detects already .running?" do
    Tempfile.open("evmpid") do |file|
      allow(MiqServer).to receive(:pidfile).and_return(file.path)
      File.write(file.path, Process.pid)

      expect(MiqServer.running?).to be_truthy
    end
  end

  describe "#active?" do
    context "Active status returns true" do
      ["starting", "started"].each do |status|
        it status do
          expect(described_class.new(:status => status).active?).to be_truthy
        end
      end
    end

    it "Inactive status returns false" do
      expect(described_class.new(:status => "stopped").active?).to be_falsey
    end
  end

  describe "#zone_description" do
    it "delegates to zone" do
      _, miq_server, zone = EvmSpecHelper.create_guid_miq_server_zone
      expect(miq_server.zone_description).to eq(zone.description)
    end
  end

  describe "#description" do
    it "doesnt blowup" do
      s = described_class.new(:name => "name")
      expect(s.description).to eq(s.name)
    end
  end
end
