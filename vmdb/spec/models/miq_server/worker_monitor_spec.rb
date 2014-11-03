require "spec_helper"

describe "MiqWorker Monitor" do

  context "After Setup," do
    before(:each) do
      MiqWorker.stub(:nice_increment).and_return("+10")
      MiqServer.any_instance.stub(:get_time_threshold).and_return(120)
      MiqServer.any_instance.stub(:get_memory_threshold).and_return(100.megabytes)
      MiqServer.any_instance.stub(:get_restart_interval).and_return(0)

      @guid               = MiqUUID.new_guid
      MiqServer.stub(:my_guid).and_return(@guid)
      @zone               = FactoryGirl.create(:zone)
      @miq_server         = FactoryGirl.create(:miq_server_not_master, :guid => @guid, :zone => @zone)
      MiqServer.my_server(true)
    end

    context "A worker" do
      before(:each) do
        @worker = FactoryGirl.create(:miq_worker, :miq_server_id => @miq_server.id, :pid => rand(20))
      end

      it "MiqServer#clean_worker_records" do
        FactoryGirl.create(:miq_worker, :miq_server_id => @miq_server.id)
        @miq_server.stub(:worker_delete)
        @worker.update_attributes(:status => MiqWorker::STATUS_STOPPED)

        @miq_server.miq_workers.length.should == 2
        ids = @miq_server.clean_worker_records
        @miq_server.miq_workers.length.should == 1
        ids.should == [@worker.id]
      end

      it "MiqServer#check_not_responding" do
        w2 = FactoryGirl.create(:miq_worker, :miq_server_id => @miq_server.id, :pid => (@worker.pid + 1))
        @miq_server.stub(:worker_delete)
        @miq_server.stub(:worker_get_monitor_status).with(@worker.pid).and_return(:waiting_for_stop)
        @miq_server.stub(:worker_get_monitor_reason).with(@worker.pid).and_return(:not_responding)
        @miq_server.stub(:worker_get_monitor_status).with(w2.pid).and_return(nil)
        @miq_server.stub(:worker_get_monitor_reason).with(w2.pid).and_return(nil)
        MiqWorker.any_instance.stub(:kill)
        @worker.update_attributes(:status => MiqWorker::STATUS_STOPPING)

        @miq_server.miq_workers.length.should == 2
        ids = @miq_server.check_not_responding
        @miq_server.miq_workers.length.should == 1
        ids.should == [@worker.id]
      end

      context "with no messages" do
        it "should not have any in its relationship" do
          @worker.messages.should be_empty
        end
      end

      it "quiesce time allowance will use message timeout" do
        @worker.stub(:current_timeout).and_return(2.minutes)
        @worker.quiesce_time_allowance.should == 2.minutes
      end

      it "quiesce time allowance will use default of 5 minutes if no message timeout" do
        @worker.stub(:current_timeout).and_return(nil)
        @worker.quiesce_time_allowance.should == 5.minutes
      end

      context "with 1 message" do
        before(:each) do
          @message = FactoryGirl.create(:miq_queue, :state => 'dequeue', :handler => @worker)
        end

        it "should have one in its relationship" do
          @worker.messages.should        == [@message]
          @worker.active_messages.should == [@message]
        end
      end

      context "with multiple messages" do
        before(:each) do
          @messages = []
          @actives  = []

          m = FactoryGirl.create(:miq_queue, :state => 'ready',   :handler => @worker, :msg_timeout => 4.minutes)
          @messages << m
          @actives  << m if m.state == 'dequeue'

          m = FactoryGirl.create(:miq_queue, :state => 'dequeue', :handler => @worker, :msg_timeout => 4.minutes)
          @messages << m
          @actives  << m if m.state == 'dequeue'

          m = FactoryGirl.create(:miq_queue, :state => 'dequeue', :handler => @worker, :msg_timeout => 5.minutes)
          @messages << m
          @actives  << m if m.state == 'dequeue'
          @worker.reload
        end

        it "should have them in its relationship" do
          @worker.messages.should        match_array @messages
          @worker.active_messages.should match_array @actives
        end

        it "on worker destroy, will destroy its processed messages" do
          @worker.destroy
          @worker.messages.all(:conditions => ["state != ?", "ready"]).size.should == 0
          @worker.active_messages.size.should   == 0
        end

        it "on worker destroy, will no longer associate the 'ready' message with the worker" do
          @worker.destroy
          MiqQueue.count(:conditions => {:state => 'ready'}).should == 1
          @worker.messages(true).size.should    ==  0

          m = @messages.first.reload
          m.handler_type.should be_nil
          m.handler_id.should be_nil
        end

        it "on worker destroy, will log a warning message for each of its message" do
          log_count = @worker.messages.count
          $log.should_receive(:warn).exactly(log_count).times
          @worker.destroy
        end

        it "should timeout the expired active messages" do
          @worker.messages.should        match_array @messages
          @worker.active_messages.should match_array @actives

          Timecop.travel 5.minutes do
            @worker.validate_active_messages
          end

          @worker.reload
          (@messages - @worker.messages).length.should        == 1
          (@actives  - @worker.active_messages).length.should == 1
          @worker.active_messages.length.should            == @actives.length - 1
          @worker.active_messages.first.msg_timeout.should == 5.minutes
        end
      end
    end

    context "A WorkerMonitor" do
      context "with active messages without worker" do
        before(:each) do
          @actives = []
          @actives << FactoryGirl.create(:miq_queue, :state => 'dequeue', :msg_timeout => 4.minutes)
          @actives << FactoryGirl.create(:miq_queue, :state => 'dequeue', :msg_timeout => 5.minutes)
        end

        it "should timeout the right active messages" do
          actives = MiqQueue.find(:all, :conditions => {:state => 'dequeue'})
          actives.length.should == @actives.length

          Timecop.travel 5.minutes do
            @miq_server.validate_active_messages
          end

          actives = MiqQueue.find(:all, :conditions => {:state => 'dequeue'})
          actives.length.should == @actives.length - 1
        end
      end

      context "with expired active messages assigned to workers from multiple" do
        before(:each) do
          @miq_server2 = FactoryGirl.create(:miq_server_not_master, :guid => MiqUUID.new_guid, :zone => @zone, :status => 'started')
          @worker1 = FactoryGirl.create(:miq_worker, :miq_server_id => @miq_server.id)
          @worker2 = FactoryGirl.create(:miq_worker, :miq_server_id => @miq_server2.id)

          @actives = []
        end

        it "should timeout messages on my server or servers that are down" do
          @actives << FactoryGirl.create(:miq_queue, :state => 'dequeue', :msg_timeout => 4.minutes, :handler => @worker1)
          @actives << FactoryGirl.create(:miq_queue, :state => 'dequeue', :msg_timeout => 4.minutes, :handler => @worker2)

          actives = MiqQueue.find(:all, :conditions => {:state => 'dequeue'})
          actives.length.should == @actives.length

          Timecop.travel 5.minutes do
            @miq_server.validate_active_messages
          end

          actives = MiqQueue.find(:all, :conditions => {:state => 'dequeue'})
          actives.length.should == @actives.length - 1
          actives.first.handler.should == @worker2

          @miq_server2.update_attribute(:status, 'stopped')

          Timecop.travel 5.minutes do
            @miq_server.validate_active_messages
          end

          actives = MiqQueue.find(:all, :conditions => {:state => 'dequeue'})
          actives.length.should == 0
        end
      end

      context "with vanilla generic worker" do
        before(:each) do
          @worker1 = FactoryGirl.create(:miq_worker, :miq_server_id => @miq_server.id, :pid => 42, :type => 'MiqGenericWorker')
          MiqServer.any_instance.stub(:get_time_threshold).and_return(2.minutes)
          MiqServer.any_instance.stub(:get_memory_threshold).and_return(500.megabytes)
          MiqServer.any_instance.stub(:get_restart_interval).and_return(0.hours)
          @miq_server.setup_drb_variables
          @miq_server.worker_add(@worker1.pid)
        end

        context "when worker exits" do
          context "because it exited" do
            before(:each) do
              @worker1.update_attributes(:status => MiqWorker::STATUS_STOPPED)
            end

            it "should delete worker row after clean_worker_records" do
              MiqWorker.count.should == 1
              MiqServer.monitor_class_names.each { |c| @miq_server.clean_worker_records(c) }
              MiqWorker.count.should == 0
            end

            context "but is waiting for restart" do
              before(:each) do
                @miq_server.stub(:worker_get_monitor_status).with(@worker1.pid).and_return(:pending_restart)
              end

              it "should not delete worker row after clean_worker_records" do
                MiqWorker.count.should == 1
                MiqServer.monitor_class_names.each { |c| @miq_server.clean_worker_records(c) }
                MiqWorker.count.should == 1
              end
            end
          end

          context "because it aborted" do
            before(:each) do
              @worker1.update_attributes(:status => MiqWorker::STATUS_ABORTED)
            end

            it "should delete worker row after clean_worker_records" do
              MiqWorker.count.should == 1
              MiqServer.monitor_class_names.each { |c| @miq_server.clean_worker_records(c) }
              MiqWorker.count.should == 0
            end
          end

          context "because it was killed" do
            before(:each) do
              @worker1.update_attributes(:status => MiqWorker::STATUS_KILLED)
            end

            it "should delete worker row after clean_worker_records" do
              MiqWorker.count.should == 1
              MiqServer.monitor_class_names.each { |c| @miq_server.clean_worker_records(c) }
              MiqWorker.count.should == 0
            end
          end
        end

        context "when worker queues up message for server" do
          before(:each) do
            @ems_id = 7
            @worker1.send_message_to_worker_monitor('reconnect_ems', "#{@ems_id}")
          end

          it "should queue up work for the server" do
            q = MiqQueue.first
            q.class_name.should  == "MiqServer"
            q.instance_id.should == @miq_server.id
            q.method_name.should == 'message_for_worker'
            q.args.should        == [@worker1.id, 'reconnect_ems', "#{@ems_id}"]
            q.queue_name.should  == 'miq_server'
            q.zone.should        == @miq_server.zone.name
            q.server_guid.should == @miq_server.guid
          end
        end

        context "when server has a single non-sync message" do
          before(:each) do
            @miq_server.message_for_worker(@worker1.id, "foo")
          end

          it "should return proper message on heartbeat via drb" do
            @miq_server.worker_heartbeat(@worker1.pid).should == [['foo']]
          end
        end

        context "when server has a single sync_config message" do
          before(:each) do
            @miq_server.message_for_worker(@worker1.id, "sync_config")
          end

          it "should return proper message on heartbeat via drb" do
            @miq_server.worker_heartbeat(@worker1.pid).should == [['sync_config', {:config=>nil}]]
          end
        end

        context "when server has a single sync_active_roles message" do
          before(:each) do
            @miq_server.message_for_worker(@worker1.id, "sync_active_roles")
          end

          it "should return proper message on heartbeat via drb" do
            @miq_server.worker_heartbeat(@worker1.pid).should == [['sync_active_roles', {:roles=>nil}]]
          end
        end

        context "#stop_worker followed by a single sync_active_roles_and_config message" do
          before(:each) do
            @miq_server.stop_worker(@worker1)
            @miq_server.message_for_worker(@worker1.id, "sync_active_roles_and_config")
          end

          it "exit message followed by active_roles and config" do
            @miq_server.worker_heartbeat(@worker1.pid).should == [['exit'], ['sync_active_roles', {:roles=>nil}], ['sync_config', {:config=>nil}]]
          end
        end

        context "when server has a single sync_active_roles_and_config message" do
          before(:each) do
            @miq_server.message_for_worker(@worker1.id, "sync_active_roles_and_config")
          end

          it "should return proper message on heartbeat via drb" do
            @miq_server.worker_heartbeat(@worker1.pid).should == [['sync_active_roles', {:roles=>nil}], ['sync_config', {:config=>nil}]]
          end
        end

        context "when server has a single reconnect_ems message with a parameter" do
          before(:each) do
            @ems_id = 7
            @miq_server.message_for_worker(@worker1.id, 'reconnect_ems', @ems_id.to_s)
          end

          it "should return proper message on heartbeat via drb" do
            @miq_server.worker_heartbeat(@worker1.pid).should == [['reconnect_ems', @ems_id.to_s]]
          end

          context "and an exit message" do
            before(:each) do
              @miq_server.message_for_worker(@worker1.id, 'exit')
            end

            it "should return proper message on heartbeat via drb" do
              @miq_server.worker_heartbeat(@worker1.pid).should == [['reconnect_ems', @ems_id.to_s], ['exit']]
            end
          end
        end

      end

      context "with worker that is using a lot of memory" do
        before(:each) do
          @worker1 = FactoryGirl.create(:miq_worker, :miq_server_id => @miq_server.id, :memory_usage => 2.gigabytes, :pid => 42)
          MiqServer.any_instance.stub(:get_time_threshold).and_return(2.minutes)
          MiqServer.any_instance.stub(:get_memory_threshold).and_return(500.megabytes)
          MiqServer.any_instance.stub(:get_restart_interval).and_return(0.hours)
          @miq_server.setup_drb_variables
        end

        it "should not trigger memory threshold if worker is creating" do
          @worker1.status = MiqWorker::STATUS_CREATING
          @miq_server.validate_worker(@worker1).should be_true
        end

        it "should not trigger memory threshold if worker is starting" do
          @worker1.status = MiqWorker::STATUS_STARTING
          @miq_server.validate_worker(@worker1).should be_true
        end

        it "should trigger memory threshold if worker is started" do
          @worker1.status = MiqWorker::STATUS_STARTED
          @miq_server.should_receive(:worker_set_monitor_status).with(@worker1.pid, :waiting_for_stop_before_restart).once
          @miq_server.validate_worker(@worker1)
        end

        it "should trigger memory threshold if worker is ready" do
          @worker1.status = MiqWorker::STATUS_READY
          @miq_server.should_receive(:worker_set_monitor_status).with(@worker1.pid, :waiting_for_stop_before_restart).once
          @miq_server.validate_worker(@worker1)
        end

        it "should trigger memory threshold if worker is working" do
          @worker1.status = MiqWorker::STATUS_WORKING
          @miq_server.should_receive(:worker_set_monitor_status).with(@worker1.pid, :waiting_for_stop_before_restart).once
          @miq_server.validate_worker(@worker1)
        end

        it "should return proper message on heartbeat" do
          @worker1.status = MiqWorker::STATUS_READY
          @miq_server.worker_heartbeat(@worker1.pid).should == []
          @miq_server.validate_worker(@worker1) # Validation will populate message
          @miq_server.worker_heartbeat(@worker1.pid).should == [['exit']]
        end

      end

    end
  end
end
