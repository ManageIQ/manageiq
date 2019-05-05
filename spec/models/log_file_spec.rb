RSpec.describe LogFile do
  context "With server and zone" do
    before do
      _, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone
      @miq_server.create_log_file_depot!(:type => "FileDepotFtpAnonymous", :uri => "test")
      @miq_server.save
    end

    it "logs_from_server will queue _request_logs with correct args" do
      task_id = described_class.logs_from_server("admin", @miq_server, :current_only => true)
      message = MiqQueue.where(:class_name => "LogFile", :method_name => "_request_logs").first
      expect(message.priority).to     eq(MiqQueue::HIGH_PRIORITY)
      expect(message.args).to         eq([{:taskid => task_id, :klass => @miq_server.class.name, :id => @miq_server.id, :current_only => true}])
      expect(message.miq_callback).to eq(:instance_id => task_id, :class_name => 'MiqTask', :method_name => :queue_callback_on_exceptions, :args => ['Finished'])
    end

    context "logs_from_server with our server" do
      before do
        @task_id  = described_class.logs_from_server("admin", @miq_server)
        @tasks    = MiqTask.all
        @task     = @tasks.first
        @messages = MiqQueue.where(:class_name => "LogFile", :method_name => "_request_logs")
        @message  = @messages.first
      end

      include_examples("Log Collection should create 1 task and 1 queue item")

      context "with a queued item not picked up, calling delete_active_log_collections" do
        # TODO: The current code will never clean up the message or task
        before do
          @miq_server.reload.delete_active_log_collections
        end

        include_examples("Log Collection should create 0 tasks and 0 queue items")
        it { expect(@miq_server).to_not be_log_collection_active }
      end

      context "with a queued item not picked up, calling delete_active_log_collections_queue twice" do
        let(:messages) { MiqQueue.where(:class_name => "MiqServer", :method_name => "delete_active_log_collections") }
        let(:message)  { messages.first }
        before do
          @miq_server.reload.delete_active_log_collections_queue
          @miq_server.delete_active_log_collections_queue
        end

        it "should create one queued delete" do
          expect(messages.length).to eq(1)
        end

        it "should have the correct attributes" do
          expect(message.instance_id).to eq(@miq_server.id)
          expect(message.server_guid).to eq(@miq_server.guid)
          expect(message.priority).to    eq(MiqQueue::HIGH_PRIORITY)
        end

        context "processing the delete queue message" do
          before do
            message.delivered(*message.deliver)
          end

          include_examples("Log Collection should create 0 tasks and 0 queue items")
          it { expect(@miq_server).to_not be_log_collection_active }
        end
      end

      context "with _request_logs queue message raising exception due to stopped server" do
        before do
          allow_any_instance_of(MiqServer).to receive_messages(:status => "stopped")
          @message.delivered(*@message.deliver)
        end

        # How does a stopped server dequeue something???
        include_examples("Log Collection should error out task and queue item")
        it { expect(@miq_server).to_not be_log_collection_active }
      end

      it "delivering MiqServer._request_logs message should call _post_my_logs with correct args" do
        expected_options = {:timeout     => described_class::LOG_REQUEST_TIMEOUT,
                            :taskid      => @task.id, :miq_task_id => nil,
                            :callback    => {:instance_id => @task.id, :class_name => 'MiqTask',
                                             :method_name => :queue_callback_on_exceptions, :args => ['Finished']}}
        expect_any_instance_of(MiqServer).to receive(:_post_my_logs).with(expected_options)

        @message.delivered(*@message.deliver)
      end

      context "with MiqServer._request_logs calling _post_my_logs to enqueue" do
        let(:message) { MiqQueue.where(:class_name => "MiqServer", :method_name => "post_logs", :instance_id => @miq_server.id, :server_guid => @miq_server.guid, :zone => @miq_server.my_zone).first }
        before do
          @message.delivered(*@message.deliver)
        end

        it "MiqServer#post_logs message should have correct args" do
          expect(message.args).to         eq([{:taskid => @task.id, :miq_task_id => nil}])
          expect(message.priority).to     eq(MiqQueue::HIGH_PRIORITY)
          expect(message.miq_callback).to eq(:instance_id => @task.id, :class_name => 'MiqTask', :method_name => :queue_callback_on_exceptions, :args => ['Finished'])
          expect(message.msg_timeout).to  eq(described_class::LOG_REQUEST_TIMEOUT)
        end

        context "with post_logs message" do
          it "#post_logs will only post current logs if flag enabled" do
            message.args.first[:only_current] = true
            expect_any_instance_of(MiqServer).to receive(:post_historical_logs).never
            expect_any_instance_of(MiqServer).to receive(:post_current_logs).once
            expect_any_instance_of(MiqServer).to receive(:post_automate_dialogs).once
            expect_any_instance_of(MiqServer).to receive(:post_automate_models).once
            message.delivered(*message.deliver)
          end

          it "#post_logs will post both historical and current logs if flag nil" do
            expect_any_instance_of(MiqServer).to receive(:post_historical_logs).once
            expect_any_instance_of(MiqServer).to receive(:post_current_logs).once
            expect_any_instance_of(MiqServer).to receive(:post_automate_dialogs).once
            expect_any_instance_of(MiqServer).to receive(:post_automate_models).once
            message.delivered(*message.deliver)
          end

          it "#post_logs will post both historical and current logs if flag false" do
            message.args.first[:only_current] = false
            expect_any_instance_of(MiqServer).to receive(:post_historical_logs).once
            expect_any_instance_of(MiqServer).to receive(:post_current_logs).once
            expect_any_instance_of(MiqServer).to receive(:post_automate_dialogs).once
            expect_any_instance_of(MiqServer).to receive(:post_automate_models).once
            message.delivered(*message.deliver)
          end
        end
      end

      context "with MiqServer _post_my_logs raising exception" do
        before do
          allow_any_instance_of(MiqServer).to receive(:_post_my_logs).and_raise
          @message.delivered(*@message.deliver)
        end

        include_examples("Log Collection should error out task and queue item")
        it { expect(@miq_server).to_not be_log_collection_active }
      end

      context "with MiqServer _post_my_logs raising timeout exception" do
        before do
          allow_any_instance_of(MiqServer).to receive(:_post_my_logs).and_raise(Timeout::Error)
          @message.delivered(*@message.deliver)
        end

        include_examples("Log Collection should error out task and queue item")
        it { expect(@miq_server).to_not be_log_collection_active }
      end

      context "with MiqServer.post_logs raising missing log_depot settings exception" do
        before do
          allow_any_instance_of(MiqServer).to receive(:log_depot).and_return(nil)
          @message.delivered(*@message.deliver)

          @message = MiqQueue.where(:class_name => "MiqServer", :method_name => "post_logs").first
          @message.delivered(*@message.deliver)
        end

        include_examples("Log Collection should error out task and queue item")
        it { expect(@miq_server).to_not be_log_collection_active }
      end

      context "with MiqServer.post_logs fully stubbed" do
        before do
          @message.delivered(*@message.deliver)
          @message = MiqQueue.where(:class_name => "MiqServer", :method_name => "post_logs").first
          allow(VMDB::Util).to receive(:zip_logs).and_return('/tmp/blah')
          allow(VMDB::Util).to receive(:get_evm_log_for_date).and_return('/tmp/blah')
          allow(VMDB::Util).to receive(:get_log_start_end_times).and_return((Time.now.utc - 600), Time.now.utc)
        end

        context "with VMDB::Util.zip_logs raising exception" do
          before do
            allow(VMDB::Util).to receive(:zip_logs).and_raise("some error message")
            @message.delivered(*@message.deliver)
          end

          include_examples("Log Collection should error out task and queue item")
          it { expect(@miq_server).to_not be_log_collection_active }
        end

        context "with VMDB::Util.zip_logs raising timeout exception" do
          before do
            allow(VMDB::Util).to receive(:zip_logs).and_raise(Timeout::Error)
            @message.delivered(*@message.deliver)
          end

          include_examples("Log Collection should error out task and queue item")
          it { expect(@miq_server).to_not be_log_collection_active }
        end

        context "with MiqServer delete_old_requested_logs raising timeout exception" do
          before do
            allow_any_instance_of(MiqServer).to receive(:delete_old_requested_logs).and_raise(Timeout::Error)
            @message.delivered(*@message.deliver)
          end

          include_examples("Log Collection should error out task and queue item")
          it { expect(@miq_server).to_not be_log_collection_active }
        end

        context "with MiqServer delete_old_requested_logs raising exception" do
          before do
            allow_any_instance_of(MiqServer).to receive(:delete_old_requested_logs).and_raise("some error message")
            @message.delivered(*@message.deliver)
          end

          include_examples("Log Collection should error out task and queue item")
          it { expect(@miq_server).to_not be_log_collection_active }
        end

        context "with MiqServer base_zip_log_name raising exception" do
          before do
            allow_any_instance_of(MiqServer).to receive(:base_zip_log_name).and_raise("some error message")
            @message.delivered(*@message.deliver)
          end

          include_examples("Log Collection should error out task and queue item")
          it { expect(@miq_server).to_not be_log_collection_active }
        end

        context "with MiqServer base_zip_log_name raising timeout exception" do
          before do
            allow_any_instance_of(MiqServer).to receive(:base_zip_log_name).and_raise(Timeout::Error)
            @message.delivered(*@message.deliver)
          end

          include_examples("Log Collection should error out task and queue item")
          it { expect(@miq_server).to_not be_log_collection_active }
        end

        context "with MiqServer format_log_time raising exception" do
          before do
            allow_any_instance_of(MiqServer).to receive(:format_log_time).and_raise("some error message")
            @message.delivered(*@message.deliver)
          end

          include_examples("Log Collection should error out task and queue item")
          it { expect(@miq_server).to_not be_log_collection_active }
        end

        context "with MiqServer format_log_time raising timeout exception" do
          before do
            allow_any_instance_of(MiqServer).to receive(:format_log_time).and_raise(Timeout::Error)
            @message.delivered(*@message.deliver)
          end

          include_examples("Log Collection should error out task and queue item")
          it { expect(@miq_server).to_not be_log_collection_active }
        end
      end
    end
  end
end
