describe "MiqWorker Monitor" do
  context "After Setup," do
    before do
      allow(MiqWorker).to receive(:nice_increment).and_return("+10")
      allow_any_instance_of(MiqServer).to receive(:get_time_threshold).and_return(120)
      allow_any_instance_of(MiqServer).to receive(:get_memory_threshold).and_return(100.megabytes)

      @miq_server = EvmSpecHelper.local_miq_server
    end

    context "A worker" do
      before do
        @worker = FactoryBot.create(:miq_worker, :miq_server_id => @miq_server.id)
      end

      it "MiqServer#clean_worker_records" do
        FactoryBot.create(:miq_worker, :miq_server_id => @miq_server.id)
        allow(@miq_server).to receive(:worker_delete)
        @worker.update(:status => MiqWorker::STATUS_STOPPED)

        expect(@miq_server.miq_workers.length).to eq(2)
        ids = @miq_server.clean_worker_records
        expect(@miq_server.miq_workers.length).to eq(1)
        expect(ids).to eq([@worker.id])
      end

      it "MiqServer#check_not_responding" do
        w2 = FactoryBot.create(:miq_worker, :miq_server_id => @miq_server.id, :pid => (@worker.pid + 1))
        allow(@miq_server).to receive(:worker_delete)
        allow(@miq_server).to receive(:worker_get_monitor_status).with(@worker.pid).and_return(:waiting_for_stop)
        allow(@miq_server).to receive(:worker_get_monitor_reason).with(@worker.pid).and_return(:not_responding)
        allow(@miq_server).to receive(:worker_get_monitor_status).with(w2.pid).and_return(nil)
        allow(@miq_server).to receive(:worker_get_monitor_reason).with(w2.pid).and_return(nil)
        allow_any_instance_of(MiqWorker).to receive(:kill)
        @worker.update(:status => MiqWorker::STATUS_STOPPING)

        expect(@miq_server.miq_workers.length).to eq(2)
        ids = @miq_server.check_not_responding
        expect(@miq_server.miq_workers.length).to eq(1)
        expect(ids).to eq([@worker.id])
      end

      describe "#do_system_limit_exceeded" do
        before do
          @worker_to_keep = FactoryBot.create(:miq_ems_metrics_processor_worker,
            :miq_server   => @miq_server,
            :memory_usage => 1.gigabytes
          )
          @worker_to_kill = FactoryBot.create(:miq_ems_metrics_processor_worker,
            :miq_server   => @miq_server,
            :memory_usage => 2.gigabytes
          )
        end

        it "will kill the worker with the highest memory" do
          expect(@miq_server).to receive(:restart_worker).with(@worker_to_kill, :memory_exceeded)
          @miq_server.do_system_limit_exceeded
        end

        it "will handle workers with nil memory_usage" do
          @worker_to_keep.update!(:memory_usage => nil)

          expect(@miq_server).to receive(:restart_worker).with(@worker_to_kill, :memory_exceeded)
          @miq_server.do_system_limit_exceeded
        end
      end

      context "with no messages" do
        it "should not have any in its relationship" do
          expect(@worker.messages).to be_empty
        end
      end

      context "with 1 message" do
        before do
          @message = FactoryBot.create(:miq_queue, :state => 'dequeue', :handler => @worker)
        end

        it "should have one in its relationship" do
          expect(@worker.messages).to eq([@message])
          expect(@worker.active_messages).to eq([@message])
        end
      end

      context "with multiple messages" do
        before do
          @messages = []
          @actives  = []

          m = FactoryBot.create(:miq_queue, :state => 'ready',   :handler => @worker, :msg_timeout => 4.minutes)
          @messages << m
          @actives << m if m.state == 'dequeue'

          m = FactoryBot.create(:miq_queue, :state => 'dequeue', :handler => @worker, :msg_timeout => 4.minutes)
          @messages << m
          @actives << m if m.state == 'dequeue'

          m = FactoryBot.create(:miq_queue, :state => 'dequeue', :handler => @worker, :msg_timeout => 5.minutes)
          @messages << m
          @actives << m if m.state == 'dequeue'
          @worker.reload
        end

        it "should have them in its relationship" do
          expect(@worker.messages).to        match_array @messages
          expect(@worker.active_messages).to match_array @actives
        end

        it "on worker destroy, will destroy its processed messages" do
          @worker.destroy
          expect(@worker.messages.where("state != ?", "ready").count).to eq(0)
          expect(@worker.active_messages.size).to eq(0)
        end

        it "on worker destroy, will no longer associate the 'ready' message with the worker" do
          @worker.destroy
          expect(MiqQueue.where(:state => 'ready').count).to eq(1)
          expect(@worker.messages.reload.size).to eq(0)

          m = @messages.first.reload
          expect(m.handler_type).to be_nil
          expect(m.handler_id).to be_nil
        end

        it "on worker destroy, will log a warning message for each of its message" do
          log_count = @worker.messages.count
          expect($log).to receive(:warn).exactly(log_count).times
          @worker.destroy
        end

        it "should timeout the expired active messages" do
          expect(@worker.messages).to        match_array @messages
          expect(@worker.active_messages).to match_array @actives

          Timecop.travel 5.minutes do
            @worker.validate_active_messages
          end

          @worker.reload
          expect((@messages - @worker.messages).length).to eq(1)
          expect((@actives - @worker.active_messages).length).to eq(1)
          expect(@worker.active_messages.length).to eq(@actives.length - 1)
          expect(@worker.active_messages.first.msg_timeout).to eq(5.minutes)
        end
      end
    end

    context "A WorkerMonitor" do
      context "with active messages without worker" do
        before do
          @actives = []
          @actives << FactoryBot.create(:miq_queue, :state => 'dequeue', :msg_timeout => 4.minutes)
          @actives << FactoryBot.create(:miq_queue, :state => 'dequeue', :msg_timeout => 5.minutes)
        end

        it "should timeout the right active messages" do
          actives = MiqQueue.where(:state => 'dequeue')
          expect(actives.length).to eq(@actives.length)

          Timecop.travel 5.minutes do
            @miq_server.validate_active_messages
          end

          actives = MiqQueue.where(:state => 'dequeue')
          expect(actives.length).to eq(@actives.length - 1)
        end
      end

      context "with expired active messages assigned to workers from multiple" do
        before do
          @miq_server2 = FactoryBot.create(:miq_server, :zone => @miq_server.zone)
          @worker1 = FactoryBot.create(:miq_worker, :miq_server_id => @miq_server.id)
          @worker2 = FactoryBot.create(:miq_worker, :miq_server_id => @miq_server2.id)

          @actives = []
        end

        it "should timeout messages on my server or servers that are down" do
          @actives << FactoryBot.create(:miq_queue, :state => 'dequeue', :msg_timeout => 4.minutes, :handler => @worker1)
          @actives << FactoryBot.create(:miq_queue, :state => 'dequeue', :msg_timeout => 4.minutes, :handler => @worker2)

          actives = MiqQueue.where(:state => 'dequeue')
          expect(actives.length).to eq(@actives.length)

          Timecop.travel 5.minutes do
            @miq_server.validate_active_messages
          end

          actives = MiqQueue.where(:state => 'dequeue')
          expect(actives.length).to eq(@actives.length - 1)
          expect(actives.first.handler).to eq(@worker2)

          @miq_server2.update_attribute(:status, 'stopped')

          Timecop.travel 5.minutes do
            @miq_server.validate_active_messages
          end

          actives = MiqQueue.where(:state => 'dequeue')
          expect(actives.length).to eq(0)
        end
      end

      context "with vanilla generic worker" do
        before do
          @worker1 = FactoryBot.create(:miq_worker, :miq_server_id => @miq_server.id, :pid => 42, :type => 'MiqGenericWorker')
          allow_any_instance_of(MiqServer).to receive(:get_time_threshold).and_return(2.minutes)
          allow_any_instance_of(MiqServer).to receive(:get_memory_threshold).and_return(500.megabytes)
          @miq_server.setup_drb_variables
          @miq_server.worker_add(@worker1.pid)
        end

        context "when worker exits" do
          context "because it exited" do
            before do
              @worker1.update(:status => MiqWorker::STATUS_STOPPED)
            end

            it "should delete worker row after clean_worker_records" do
              expect(MiqWorker.count).to eq(1)
              MiqServer.monitor_class_names.each { |c| @miq_server.clean_worker_records(c) }
              expect(MiqWorker.count).to eq(0)
            end
          end

          context "because it aborted" do
            before do
              @worker1.update(:status => MiqWorker::STATUS_ABORTED)
            end

            it "should delete worker row after clean_worker_records" do
              expect(MiqWorker.count).to eq(1)
              MiqServer.monitor_class_names.each { |c| @miq_server.clean_worker_records(c) }
              expect(MiqWorker.count).to eq(0)
            end
          end

          context "because it was killed" do
            before do
              @worker1.update(:status => MiqWorker::STATUS_KILLED)
            end

            it "should delete worker row after clean_worker_records" do
              expect(MiqWorker.count).to eq(1)
              MiqServer.monitor_class_names.each { |c| @miq_server.clean_worker_records(c) }
              expect(MiqWorker.count).to eq(0)
            end
          end
        end

        context "when worker queues up message for server" do
          before do
            @ems_id = 7
            @worker1.send_message_to_worker_monitor('reconnect_ems', @ems_id.to_s)
          end

          it "should queue up work for the server" do
            q = MiqQueue.first
            expect(q.class_name).to eq("MiqServer")
            expect(q.instance_id).to eq(@miq_server.id)
            expect(q.method_name).to eq('message_for_worker')
            expect(q.args).to eq([@worker1.id, 'reconnect_ems', @ems_id.to_s])
            expect(q.queue_name).to eq('miq_server')
            expect(q.zone).to eq(@miq_server.zone.name)
            expect(q.server_guid).to eq(@miq_server.guid)
          end
        end

        context "when server has a single non-sync message" do
          before do
            @miq_server.message_for_worker(@worker1.id, "foo")
          end

          it "should return proper message on heartbeat via drb" do
            expect(@miq_server.worker_heartbeat(@worker1.pid)).to eq([['foo']])
          end
        end

        context "when server has a single sync_config message" do
          before do
            @miq_server.message_for_worker(@worker1.id, "sync_config")
          end

          it "should return proper message on heartbeat via drb" do
            expect(@miq_server.worker_heartbeat(@worker1.pid)).to eq([['sync_config']])
          end
        end

        context "when server has a single reconnect_ems message with a parameter" do
          before do
            @ems_id = 7
            @miq_server.message_for_worker(@worker1.id, 'reconnect_ems', @ems_id.to_s)
          end

          it "should return proper message on heartbeat via drb" do
            expect(@miq_server.worker_heartbeat(@worker1.pid)).to eq([['reconnect_ems', @ems_id.to_s]])
          end

          context "and an exit message" do
            before do
              @miq_server.message_for_worker(@worker1.id, 'exit')
            end

            it "should return proper message on heartbeat via drb" do
              expect(@miq_server.worker_heartbeat(@worker1.pid)).to eq([['reconnect_ems', @ems_id.to_s], ['exit']])
            end
          end
        end

        context "for messaging through a key store" do
          before do
            allow(@miq_server).to receive(:key_store).and_return(@key_store)
            @ts = Time.now.utc
          end

          it "should update timestamp with config or role changes" do
            expect(@miq_server).to receive(:set_last_change).with("last_config_change", @ts)
            @miq_server.update_sync_timestamp(@ts)
          end
        end
      end

      context "threshold validation" do
        let(:worker) { FactoryBot.create(:miq_worker, :miq_server_id => server.id, :pid => 42) }
        let(:server) { @miq_server }

        before do
          allow(server).to receive(:get_time_threshold).and_return(2.minutes)
          allow(server).to receive(:get_memory_threshold).and_return(500.megabytes)
          server.setup_drb_variables
        end

        context "for heartbeat" do
          it "should mark not responding if not recently heartbeated via Drb" do
            worker.update(:last_heartbeat => 20.minutes.ago)
            expect(server.validate_worker(worker)).to be_falsey
            expect(worker.reload.status).to eq(MiqWorker::STATUS_STOPPING)
          end

          context "to a file" do
            before do
              ENV["WORKER_HEARTBEAT_METHOD"] = "file"
            end

            after do
              ENV["WORKER_HEARTBEAT_METHOD"] = nil
            end

            it "should mark not responding if not recently heartbeated via file" do
              allow(server).to receive(:workers_last_heartbeat_to_file).and_return(20.minutes.ago)

              expect(server.validate_worker(worker)).to be_falsey
              expect(worker.reload.status).to eq(MiqWorker::STATUS_STOPPING)
            end

            it "should detect responding if recently heartbeated via file" do
              expect(server.validate_worker(worker)).to be_truthy
              expect(worker.reload.status).to eq(MiqWorker::STATUS_READY)
            end
          end
        end

        context "for excessive memory" do
          before { worker.memory_usage = 2.gigabytes }

          it "should not trigger memory threshold if worker is creating" do
            worker.status = MiqWorker::STATUS_CREATING
            expect(server.validate_worker(worker)).to be_truthy
          end

          it "should not trigger memory threshold if worker is starting" do
            worker.status = MiqWorker::STATUS_STARTING
            expect(server.validate_worker(worker)).to be_truthy
          end

          it "should trigger memory threshold if worker is started" do
            worker.status = MiqWorker::STATUS_STARTED
            expect(server).to receive(:worker_set_monitor_status).with(worker.pid, :waiting_for_stop_before_restart).once
            server.validate_worker(worker)
          end

          it "should trigger memory threshold if worker is ready" do
            worker.status = MiqWorker::STATUS_READY
            expect(server).to receive(:worker_set_monitor_status).with(worker.pid, :waiting_for_stop_before_restart).once
            server.validate_worker(worker)
          end

          it "should trigger memory threshold if worker is working" do
            worker.status = MiqWorker::STATUS_WORKING
            expect(server).to receive(:worker_set_monitor_status).with(worker.pid, :waiting_for_stop_before_restart).once
            server.validate_worker(worker)
          end

          it "should return proper message on heartbeat" do
            worker.status = MiqWorker::STATUS_READY
            expect(server.worker_heartbeat(worker.pid)).to eq([])
            server.validate_worker(worker) # Validation will populate message
            expect(server.worker_heartbeat(worker.pid)).to eq([['exit']])
          end
        end
      end
    end
  end
end
