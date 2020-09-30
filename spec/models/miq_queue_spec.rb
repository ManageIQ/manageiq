RSpec.describe MiqQueue do
  specify { expect(FactoryBot.build(:miq_queue)).to be_valid }

  context "#deliver" do
    before do
      _, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone
    end

    it "requires class_name" do
      msg = MiqQueue.new(:class_name => nil)
      status, message, result = msg.deliver
      expect(status).to eq(MiqQueue::STATUS_ERROR)
      expect(message).to eq("class_name cannot be nil")
      expect(result).to be_nil
    end

    it "requires valid class_name" do
      msg = MiqQueue.new(:class_name => "NotARealClazz")
      status, message, result = msg.deliver
      expect(status).to eq(MiqQueue::STATUS_ERROR)
      expect(message).to eq("uninitialized constant NotARealClazz")
      expect(result).to be_nil
    end

    it "uses class_name without instance_id" do
      expect(MiqServer).to receive(:my_zone).and_return("MY ZONE")
      msg = MiqQueue.new(:class_name => "MiqServer", :method_name => "my_zone")

      status, message, result = msg.deliver
      expect(status).to eq(MiqQueue::STATUS_OK)
      expect(message).to eq("Message delivered successfully")
      expect(result).to eq("MY ZONE")
    end

    it "uses object with instance_id" do
      msg = MiqQueue.new(:class_name => "MiqServer", :instance_id => @miq_server.id, :method_name => "my_zone")

      status, message, result = msg.deliver
      expect(status).to eq(MiqQueue::STATUS_OK)
      expect(message).to eq("Message delivered successfully")
      expect(result).to eq(@miq_server.my_zone)
    end

    it "handles record not found" do
      invalid_server_id = MiqServer.maximum(:id) + 1
      msg = MiqQueue.new(:class_name => "MiqServer", :instance_id => invalid_server_id, :method_name => "my_zone")

      expect(msg._log).to receive(:warn).with(/will not be delivered because/)

      status, message, result = msg.deliver
      expect(status).to eq(MiqQueue::STATUS_WARN)
      expect(message).to be_nil
      expect(result).to be_nil
    end

    it "passes multiple args" do
      expect(Storage).to receive(:scan_queue).with("1", "2").and_return("WHATEVER")
      msg = MiqQueue.new(:class_name => "Storage", :method_name => "scan_queue", :args => %w[1 2])

      status, message, result = msg.deliver
      expect(status).to eq(MiqQueue::STATUS_OK)
      expect(message).to eq("Message delivered successfully")
      expect(result).to eq("WHATEVER")
    end

    it "passes data" do
      expect(Storage).to receive(:scan_queue).with(1, "2").and_return("STUFF")
      msg = MiqQueue.new(:class_name => "Storage", :method_name => "scan_queue", :data => "2", :args => [1])

      status, message, result = msg.deliver
      expect(status).to eq(MiqQueue::STATUS_OK)
      expect(message).to eq("Message delivered successfully")
      expect(result).to eq("STUFF")
    end

    it "passes target_id" do
      expect(MiqServer).to receive(:my_zone).with(1).and_return("MY ZONE")
      msg = MiqQueue.new(:class_name => "MiqServer", :method_name => "my_zone", :target_id => "1")

      status, message, result = msg.deliver
      expect(status).to eq(MiqQueue::STATUS_OK)
      expect(message).to eq("Message delivered successfully")
      expect(result).to eq("MY ZONE")
    end

    it "doesn't pass target_id if an instance_id is passed" do
      expect(MiqServer).to receive(:find).with(@miq_server.id).and_return(@miq_server)
      expect(@miq_server).to receive(:my_zone).and_return("MY ZONE")
      msg = MiqQueue.new(:class_name => "MiqServer", :instance_id => @miq_server.id, :method_name => "my_zone", :target_id => @miq_server.id)

      status, message, result = msg.deliver
      expect(status).to eq(MiqQueue::STATUS_OK)
      expect(message).to eq("Message delivered successfully")
      expect(result).to eq("MY ZONE")
    end

    it "handles timeout errors" do
      expect(MiqServer).to receive(:my_zone).and_raise(Timeout::Error, "timeout issue")
      msg = MiqQueue.new(:class_name => "MiqServer", :method_name => "my_zone")

      expect(msg._log).to receive(:error).with(/timed out after/)

      status, message, result = msg.deliver
      expect(status).to eq(MiqQueue::STATUS_TIMEOUT)
      expect(message).to match(/timed out after/)
      expect(result).to be_nil
    end

    it "works with MiqQueueRetryLater(deliver_on)" do
      deliver_on = Time.now.utc + 1.minute
      allow(Storage).to receive(:scan_eligible_storages).and_raise(MiqException::MiqQueueRetryLater.new(:deliver_on => deliver_on))
      msg = FactoryBot.build(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :handler => @miq_server, :class_name => 'Storage', :method_name => 'scan_eligible_storages')
      status, message, result = msg.deliver

      expect(status).to eq(MiqQueue::STATUS_RETRY)
      expect(message).to match(/Message not processed/)

      expect(result).to be_nil
      expect(msg.state).to eq(MiqQueue::STATE_READY)
      expect(msg.handler).to    be_nil
      expect(msg.deliver_on).to eq(deliver_on)

      allow(Storage).to receive(:scan_timer).and_raise(MiqException::MiqQueueRetryLater.new)
      msg.state   = MiqQueue::STATE_DEQUEUE
      msg.handler = @miq_server
      status, _message, _result = msg.deliver

      expect(status).to eq(MiqQueue::STATUS_RETRY)
      expect(msg.state).to eq(MiqQueue::STATE_READY)
      expect(msg.handler).to be_nil
    end

    it "sets last_exception on raised Exception" do
      ex = StandardError.new("something blewup")
      allow(MiqServer).to receive(:pidfile).and_raise(ex)
      msg = FactoryBot.build(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :handler => @miq_server, :class_name => 'MiqServer', :method_name => 'pidfile')
      expect(msg._log).to receive(:error).with(/Error:/)
      expect(msg._log).to receive(:log_backtrace)
      status, message, _result = msg.deliver
      expect(status).to eq(MiqQueue::STATUS_ERROR)
      expect(message).to eq("something blewup")
      expect(msg.last_exception).to eq(ex)
    end
  end

  describe "user_context" do
    it "sets the User.current_user" do
      user = FactoryBot.create(:user_with_group, :name => 'Freddy Kreuger')
      msg = FactoryBot.create(:miq_queue, :state       => MiqQueue::STATE_DEQUEUE,
                                          :handler     => @miq_server,
                                          :class_name  => 'Storage',
                                          :method_name => 'create_scan_task',
                                          :user_id     => user.id,
                                          :args        => [1, 2, 3],
                                          :group_id    => user.current_group.id,
                                          :tenant_id   => user.current_tenant.id)
      expect(Storage).to receive(:create_scan_task) do
        expect(User.current_user.name).to eq(user.name)
        expect(User.current_user.current_group.id).to eq(user.current_user.current_group.id)
        expect(User.current_user.current_tenant.id).to eq(user.current_user.current_tenant.id)
        expect(args).to eq([1, 2, 3])
      end

      msg.deliver
    end
  end

  describe "#check_for_timeout" do
    it "will destroy a dequeued message when it times out" do
      handler = FactoryBot.create(:miq_ems_refresh_worker)
      msg = FactoryBot.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :handler => handler, :msg_timeout => 1.minute)

      Timecop.travel(10.minutes) do
        expect($log).to receive(:warn)
        expect(msg).to receive(:destroy)
        msg.check_for_timeout
      end
    end
  end

  describe ".check_for_timeout" do
    it "will destroy all timed out dequeued messages" do
      handler = FactoryBot.create(:miq_ems_refresh_worker)
      msg1 = FactoryBot.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :handler => handler, :msg_timeout => 1.minute)
      msg2 = FactoryBot.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :handler => handler, :msg_timeout => 2.minutes)
      msg3 = FactoryBot.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :handler => handler, :msg_timeout => 10.minutes)

      Timecop.travel(5.minutes) do
        described_class.check_for_timeout
        expect(described_class.find_by(:id => msg1.id)).to be_nil
        expect(described_class.find_by(:id => msg2.id)).to be_nil
        expect(described_class.find_by(:id => msg3.id)).to_not be_nil
      end
    end
  end

  describe ".candidates_for_timeout" do
    it "returns only messages in dequeue state which are outside their timeout" do
      FactoryBot.create(:miq_queue, :state => MiqQueue::STATE_READY, :msg_timeout => 1.minute) # not in dequeue
      FactoryBot.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :msg_timeout => 10.minutes) # not timed out

      expected_ids = []
      expected_ids << FactoryBot.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :msg_timeout => 1.minute).id
      expected_ids << FactoryBot.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :msg_timeout => 2.minutes).id

      Timecop.travel(5.minutes) do
        expect(described_class.candidates_for_timeout.pluck(:id)).to match_array(expected_ids)
      end
    end
  end

  it "should validate formatting of message for logging" do
    # Add various key/value combos as needs arise...
    message_parms = [{
      :target_id    => nil,
      :priority     => 20,
      :method_name  => 'perf_rollup_gap',
      :state        => 'ready',
      :task_id      => nil,
      :queue_name   => 'ems_metrics_processor',
      :class_name   => 'Metric::Rollup',
      :instance_id  => nil,
      :args         => [],
      :zone         => 'default',
      :role         => 'ems_metrics_processor',
      :server_guid  => nil,
      :msg_timeout  => 600,
      :handler_type => nil
    }]

    message_parms.each do |mparms|
      msg = FactoryBot.create(:miq_queue)
      mparms.each { |k, v| msg.send("#{k}=", v) }
      expect(MiqQueue.format_short_log_msg(msg)).to eq("Message id: [#{msg.id}]")
      expect(MiqQueue.format_full_log_msg(msg)).to eq("Message id: [#{msg.id}], #{msg.handler_type} id: [#{msg.handler_id}], Zone: [#{msg.zone}], Role: [#{msg.role}], Server: [#{msg.server_guid}], MiqTask id: [#{msg.miq_task_id}], Ident: [#{msg.queue_name}], Target id: [#{msg.target_id}], Instance id: [#{msg.instance_id}], Task id: [#{msg.task_id}], Command: [#{msg.class_name}.#{msg.method_name}], Timeout: [#{msg.msg_timeout}], Priority: [#{msg.priority}], State: [#{msg.state}], Deliver On: [#{msg.deliver_on}], Data: [#{msg.data.nil? ? "" : "#{msg.data.length} bytes"}], Args: #{msg.args.inspect}")
    end
  end

  it "should validate formatting of message with encrypted password in args for logging" do
    # Some reasonably accurate test data.
    args_test = [
      "[datastore1] test-cfme-vddk2/test-cfme-vddk2.vmx",
      "---ems: ems: :address: 16.16.52.50 :hostname: 16.16.52.50 :ipaddress: 16.16.52.50 :username: administrator :password: v2:{lalala} :class_name: ManageIQ::Providers::Vmware::InfraManager host: :address: 16.16.52.50 :hostname: myhost.redhat.com :ipaddress: 16.16.52.50 :username: root :password: v1:{lalala} :class_name: ManageIQ::Providers::Vmware::InfraManager::HostEsx connect_to: host snapshot: use_existing: false"
    ]

    args_cleaned_password = [
      "[datastore1] test-cfme-vddk2/test-cfme-vddk2.vmx",
      "---ems: ems: :address: 16.16.52.50 :hostname: 16.16.52.50 :ipaddress: 16.16.52.50 :username: administrator :password: ******** :class_name: ManageIQ::Providers::Vmware::InfraManager host: :address: 16.16.52.50 :hostname: myhost.redhat.com :ipaddress: 16.16.52.50 :username: root :password: ******** :class_name: ManageIQ::Providers::Vmware::InfraManager::HostEsx connect_to: host snapshot: use_existing: false"
    ]

    message_parms = [{
      :target_id    => nil,
      :priority     => 20,
      :method_name  => 'perf_rollup_gap',
      :state        => 'ready',
      :task_id      => nil,
      :queue_name   => 'ems_metrics_processor',
      :class_name   => 'Metric::Rollup',
      :instance_id  => nil,
      :args         => args_test,
      :zone         => 'default',
      :role         => 'ems_metrics_processor',
      :server_guid  => nil,
      :msg_timeout  => 600,
      :handler_type => nil
    }]

    message_parms.each do |mparms|
      msg = FactoryBot.build(:miq_queue, mparms)
      expect(MiqQueue.format_short_log_msg(msg)).to eq("Message id: [#{msg.id}]")
      expect(MiqQueue.format_full_log_msg(msg)).to eq("Message id: [#{msg.id}], #{msg.handler_type} id: [#{msg.handler_id}], Zone: [#{msg.zone}], Role: [#{msg.role}], Server: [#{msg.server_guid}], MiqTask id: [#{msg.miq_task_id}], Ident: [#{msg.queue_name}], Target id: [#{msg.target_id}], Instance id: [#{msg.instance_id}], Task id: [#{msg.task_id}], Command: [#{msg.class_name}.#{msg.method_name}], Timeout: [#{msg.msg_timeout}], Priority: [#{msg.priority}], State: [#{msg.state}], Deliver On: [#{msg.deliver_on}], Data: [#{msg.data.nil? ? "" : "#{msg.data.length} bytes"}], Args: #{args_cleaned_password.inspect}")
    end
  end

  context "executing priority" do
    it "should return adjusted value" do
      expect(MiqQueue.priority(:max)).to eq(MiqQueue::MAX_PRIORITY)
      expect(MiqQueue.priority(:high)).to eq(MiqQueue::HIGH_PRIORITY)
      expect(MiqQueue.priority(:normal)).to eq(MiqQueue::NORMAL_PRIORITY)
      expect(MiqQueue.priority(:low)).to eq(MiqQueue::LOW_PRIORITY)
      expect(MiqQueue.priority(:min)).to eq(MiqQueue::MIN_PRIORITY)

      expect(MiqQueue.priority(5000)).to eq(MiqQueue::MIN_PRIORITY)
      expect(MiqQueue.priority(-5000)).to eq(MiqQueue::MAX_PRIORITY)
      expect(MiqQueue.priority(100)).to eq(100)

      expect { MiqQueue.priority(:other)        }.to raise_error(ArgumentError)
      expect { MiqQueue.priority(:high, :other) }.to raise_error(ArgumentError)

      expect(MiqQueue.priority(:normal, :higher, 10)).to eq(MiqQueue::NORMAL_PRIORITY - 10)
      expect(MiqQueue.priority(:normal, :lower,  10)).to eq(MiqQueue::NORMAL_PRIORITY + 10)

      expect(MiqQueue.priority(:min, :lower,  1)).to eq(MiqQueue::MIN_PRIORITY)
      expect(MiqQueue.priority(:max, :higher, 1)).to eq(MiqQueue::MAX_PRIORITY)
    end

    it "should validate comparisons" do
      expect(MiqQueue.higher_priority(MiqQueue::MIN_PRIORITY, MiqQueue::MAX_PRIORITY)).to eq(MiqQueue::MAX_PRIORITY)
      expect(MiqQueue.higher_priority(MiqQueue::MAX_PRIORITY, MiqQueue::MIN_PRIORITY)).to eq(MiqQueue::MAX_PRIORITY)
      expect(MiqQueue.higher_priority?(MiqQueue::MIN_PRIORITY, MiqQueue::MAX_PRIORITY)).to be_falsey
      expect(MiqQueue.higher_priority?(MiqQueue::MAX_PRIORITY, MiqQueue::MIN_PRIORITY)).to be_truthy

      expect(MiqQueue.lower_priority(MiqQueue::MIN_PRIORITY,  MiqQueue::MAX_PRIORITY)).to eq(MiqQueue::MIN_PRIORITY)
      expect(MiqQueue.lower_priority(MiqQueue::MAX_PRIORITY,  MiqQueue::MIN_PRIORITY)).to eq(MiqQueue::MIN_PRIORITY)
      expect(MiqQueue.lower_priority?(MiqQueue::MIN_PRIORITY,  MiqQueue::MAX_PRIORITY)).to be_truthy
      expect(MiqQueue.lower_priority?(MiqQueue::MAX_PRIORITY,  MiqQueue::MIN_PRIORITY)).to be_falsey
    end
  end

  context "deliver to queue" do
    before do
      _, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone

      @t1 = Time.parse("Wed Apr 20 00:15:00 UTC 2011")
      @msg = FactoryBot.create(:miq_queue, :zone => @zone.name, :role => "role1", :priority => 20, :created_on => @t1)
    end

    it "should requeue a message with new message id" do
      options = {
        :class_name  => 'MiqAeEngine',
        :method_name => 'deliver',
        :args        => ['rq_message', 1, ["A", "B", "C"], 'AUTOMATION', 'gp', 'warn', 'automate message', 'ae_fsm_started', 'ae_state_started', 'ae_state_retries'],
        :zone        => @zone.name,
        :role        => 'automate',
        :msg_timeout => 60.minutes,
        :no_such_key => 'Does not exist'
      }

      @msg.update!(:state => 'error')
      @old_msg_id = @msg.id

      @new_msg = @msg.requeue(options)
      @new_msg_id = @new_msg.id

      expect(@new_msg.attributes.keys.exclude?('no_such_key')).to be_truthy
      expect(@msg.id).not_to eq(@msg.requeue(options).id)
    end

    it "should requeue a message with message id higher last" do
      options = {
        :class_name  => 'MiqAeEngine',
        :method_name => 'deliver',
        :args        => ['rq_message', 1, ["A", "B", "C"], 'AUTOMATION', 'gp', 'warn', 'automate message', 'ae_fsm_started', 'ae_state_started', 'ae_state_retries'],
        :zone        => @zone.name,
        :role        => 'automate',
        :msg_timeout => 60.minutes
      }

      @old_msg_id = @msg.id

      @new_msg = @msg.requeue(options)
      @new_msg_id = @new_msg.id

      expect(@msg.requeue(options).id).to be > @msg.id
    end

    it "should requeue a message" do
      hash_value = "test_string_2_05312011"
      @msg.data = hash_value
      expect(@msg.data).to eq("test_string_2_05312011")
    end
  end

  context "worker" do
    before do
      _, @miq_server, = EvmSpecHelper.create_guid_miq_server_zone

      @worker = FactoryBot.create(:miq_ems_refresh_worker, :miq_server_id => @miq_server.id)
      @msg = FactoryBot.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :task_id => "task123", :handler => @worker)
    end

    it "should find a message by task id" do
      expect(MiqQueue.get_worker("task123")).to eq(@worker)
    end

    it "should return worker handler" do
      expect(@msg.get_worker).to eq(@worker)
    end
  end

  context "#put" do
    before do
      MiqRegion.seed
      Zone.seed
      _, @miq_server, = EvmSpecHelper.create_guid_miq_server_zone
    end

    it "should put one message on queue" do
      msg = MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1, 2]
      )

      expect(MiqQueue.get).to eq(msg)
      expect(MiqQueue.get).to eq(nil)
    end

    it "should skip putting message on queue in maintenance zone" do
      MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1, 2],
        :zone        => Zone.maintenance_zone.name
      )
      expect(MiqQueue.count).to eq(0)
    end

    it "should accept non-Array args (for now)" do
      begin
        class MiqQueueSpecNonArrayArgs
          def self.some_method(single_arg)
            single_arg
          end
        end

        msg = MiqQueue.put(
          :class_name  => "MiqQueueSpecNonArrayArgs",
          :method_name => "some_method",
          :args        => "not_an_array"
        )

        msg_from_db = MiqQueue.find(msg.id)
        expect(msg_from_db.args).to eq(["not_an_array"])

        _, _, result = msg_from_db.deliver
        expect(result).to eq "not_an_array"
      ensure
        Object.send(:remove_const, :MiqQueueSpecNonArrayArgs)
      end
    end

    it "defaults :args" do
      msg = MiqQueue.put(
        :class_name  => "Class1",
        :method_name => "Method1"
      )

      msg_from_db = MiqQueue.find(msg.id)
      expect(msg_from_db.args).to eq([])
    end

    it "defaults :miq_callback" do
      msg = MiqQueue.put(
        :class_name  => "Class1",
        :method_name => "Method1"
      )

      msg_from_db = MiqQueue.find(msg.id)
      expect(msg_from_db.miq_callback).to eq({})
    end

    it "creates with :miq_callback" do
      miq_callback = {
        :class_name  => "Class1",
        :method_name => "callback_method",
      }

      msg = MiqQueue.put(
        :class_name   => "Class1",
        :method_name  => "Method1",
        :miq_callback => miq_callback
      )

      msg_from_db = MiqQueue.find(msg.id)
      expect(msg_from_db.miq_callback).to include(miq_callback)
    end

    it "creates with :miq_callback via create_with" do
      miq_callback = {
        :class_name  => "Class1",
        :method_name => "callback_method"
      }

      msg = MiqQueue.create_with(:miq_callback => miq_callback).put(
        :class_name  => "Class1",
        :method_name => "Method1"
      )

      msg_from_db = MiqQueue.find(msg.id)
      expect(msg_from_db.miq_callback).to include(miq_callback)
    end

    it "does not allow objects on the queue" do
      expect do
        MiqQueue.put(:class_name => 'MyClass', :method_name => 'method1', :args => [MiqServer.first])
      end.to raise_error(ArgumentError)
    end

    it "defaults :queue_name" do
      msg = MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1, 2]
      )
      expect(msg.queue_name).to eq("generic")
    end

    it "sets other :queue_name" do
      msg = MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1, 2],
        :queue_name  => "other"
      )
      expect(msg.queue_name).to eq("other")
    end

    it "defaults :priority" do
      msg = MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1, 2]
      )
      expect(msg.priority).to eq(MiqQueue::NORMAL_PRIORITY)
    end

    it "sets :prority" do
      msg = MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1, 2],
        :priority    => MiqQueue::LOW_PRIORITY
      )
      expect(msg.priority).to eq(MiqQueue::LOW_PRIORITY)
    end

    it "creates with :prority via create_with" do
      msg = MiqQueue.create_with(:priority => MiqQueue::LOW_PRIORITY).put(
        :class_name  => "Class1",
        :method_name => "Method1"
      )

      expect(msg.priority).to eq(MiqQueue::LOW_PRIORITY)
    end

    it "defaults :role" do
      msg = MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1, 2]
      )
      expect(msg.role).to eq(nil)
    end

    it "defaults :server_guid" do
      msg = MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1, 2]
      )
      expect(msg.server_guid).to eq(nil)
    end

    it "defaults :msg_timeout" do
      msg = MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1, 2]
      )
      expect(msg.msg_timeout).to eq(MiqQueue::TIMEOUT)
    end

    it "sets :msg_timeout" do
      msg = MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1, 2],
        :msg_timeout => 3.minutes
      )
      expect(msg.msg_timeout).to eq(3.minutes)
    end

    it "sets :msg_timeout via create_with" do
      msg = MiqQueue.create_with(:msg_timeout => 3.minutes).put(
        :class_name  => "Class1",
        :method_name => "Method1"
      )

      expect(msg.msg_timeout).to eq(3.minutes)
    end

    it "defaults :deliver_on" do
      msg = MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1, 2]
      )
      expect(msg.deliver_on).to eq(nil)
    end

    it "creates with :deliver_on" do
      deliver_on = 10.minutes.ago.change(:usec => 0)

      msg = MiqQueue.put(
        :class_name  => "Class1",
        :method_name => "Method1",
        :deliver_on  => deliver_on
      )

      msg_from_db = MiqQueue.find(msg.id)
      expect(msg_from_db.deliver_on).to eq(deliver_on)
    end

    it "creates with :deliver_on via create_with" do
      deliver_on = 10.minutes.ago.change(:usec => 0)

      msg = MiqQueue.create_with(:deliver_on => deliver_on).put(
        :class_name  => "Class1",
        :method_name => "Method1"
      )

      msg_from_db = MiqQueue.find(msg.id)
      expect(msg_from_db.deliver_on).to eq(deliver_on)
    end
  end

  context "#put_unless_exists" do
    before do
      _, @miq_server, = EvmSpecHelper.create_guid_miq_server_zone
    end

    it "should put a unique message on the queue if method_name is different" do
      msg1 = MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1, 2]
      )
      msg2 = MiqQueue.put_unless_exists(
        :class_name  => 'MyClass',
        :method_name => 'method2',
        :args        => [1, 2]
      )

      expect(MiqQueue.get).to eq(msg1)
      expect(MiqQueue.get).to eq(msg2)
      expect(MiqQueue.get).to eq(nil)
    end

    it "should ignore state when putting a new message on the queue" do
      MiqQueue.put_unless_exists(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1, 2]
      )

      expect(MiqQueue.first.state).to eq(MiqQueue::STATE_READY)
    end

    it "should yield object found" do
      MiqQueue.put_unless_exists(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1, 2]
      ) do |msg, _find_options|
        expect(msg).to be_nil
        nil
      end
      MiqQueue.put_unless_exists(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1, 2]
      ) do |msg, _find_options|
        expect(msg).not_to be_nil
        nil
      end
    end

    it "should not put duplicate messages on the queue" do
      msg1 = MiqQueue.put_unless_exists(
        :class_name  => 'MyClass',
        :method_name => 'method2',
        :args        => [1, 2]
      )

      MiqQueue.put_unless_exists(
        :class_name  => 'MyClass',
        :method_name => 'method2',
        :args        => [1, 2]
      )

      expect(MiqQueue.get).to eq(msg1)
      expect(MiqQueue.get).to eq(nil)
    end

    it "should add create_with options" do
      MiqQueue.create_with(:args => [3, 3]).put_unless_exists(
        :class_name  => 'MyClass',
        :method_name => 'method1'
      )

      expect(MiqQueue.first.args).to eq([3, 3])
    end

    it "should not update create_with options" do
      MiqQueue.create_with(:args => [3, 3]).put_unless_exists(
        :class_name  => 'MyClass',
        :method_name => 'method1'
      )

      MiqQueue.create_with(:args => [1, 2]).put_unless_exists(
        :class_name  => 'MyClass',
        :method_name => 'method1'
      )

      expect(MiqQueue.first.args).to eq([3, 3])
    end
  end

  context "#put_or_update" do
    before do
      _, @miq_server, = EvmSpecHelper.create_guid_miq_server_zone
    end

    it "should respect hash updates in put_or_update for create" do
      MiqQueue.put_or_update(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1, 2]
      ) do |_msg, find_options|
        find_options.merge(:args => [3, 3])
      end

      expect(MiqQueue.first.args).to eq([3, 3])
    end

    it "should respect hash updates in put_or_update for update" do
      MiqQueue.put_or_update(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1, 2]
      )

      expect(MiqQueue.first.args).to eq([1, 2])

      MiqQueue.put_or_update(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1, 2]
      ) do |_msg, find_options|
        find_options.merge(:args => [3, 3])
      end

      expect(MiqQueue.first.args).to eq([3, 3])
    end

    it "supports a Class object for the class name(deprecated)" do
      expect(ActiveSupport::Deprecation).to receive(:warn).with(/use a String for class_name/, anything)
      msg = MiqQueue.put_or_update(:class_name => MiqServer, :instance_id => @miq_server.id, :method_name => "my_zone")

      status, message, result = msg.deliver
      expect(status).to eq(MiqQueue::STATUS_OK)
      expect(message).to eq("Message delivered successfully")
      expect(result).to eq(@miq_server.my_zone)
    end

    it "should use args param to find messages on the queue" do
      MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1, 2],
        :task_id     => 'first_task'
      )
      MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [3, 4],
        :task_id     => 'booring_task'
      )

      MiqQueue.put_or_update(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [3, 4]
      ) do |_msg, params|
        params.merge(:task_id => 'fun_task')
      end

      expect(MiqQueue.get).to have_attributes(:args => [1, 2], :task_id => 'first_task')
      expect(MiqQueue.get).to have_attributes(:args => [3, 4], :task_id => 'fun_task')
      expect(MiqQueue.get).to eq(nil)
    end
  end

  describe ".broadcast" do
    let(:queue_params) do
      {
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1, 2]
      }
    end

    def queue_items
      MiqQueue.where(queue_params.slice(:class_name, :method_name))
    end

    context "with no servers" do
      it "nothing is created" do
        MiqQueue.broadcast(queue_params)

        expect(queue_items.count).to eq(0)
      end
    end

    context "with a single server" do
      it "creates a queue item for the server" do
        EvmSpecHelper.create_guid_miq_server_zone
        MiqQueue.broadcast(queue_params)

        expect(queue_items.count).to eq(1)
        expect(MiqQueue.get).to have_attributes(queue_params)
      end
    end

    context "with servers in two different zones" do
      let(:other_role) { FactoryBot.create(:server_role, :name => "other_role") }
      let(:other_zone) { FactoryBot.create(:zone) }

      # NOTE: `.create_list` doesn't work with `:guid`
      let(:other_servers) do
        [
          FactoryBot.create(:miq_server, :guid => SecureRandom.uuid, :zone => other_zone),
          FactoryBot.create(:miq_server, :guid => SecureRandom.uuid, :zone => other_zone)
        ]
      end

      before do
        EvmSpecHelper.create_guid_miq_server_zone
        other_servers.last.role = other_role.name
      end

      it "creates a queue item for the server" do
        MiqQueue.broadcast(queue_params)

        expect(queue_items.count).to eq(3)

        (other_servers + [MiqServer.my_server]).each do |server|
          EvmSpecHelper.stub_as_local_server(server)

          expect(MiqQueue.get).to have_attributes(queue_params)
        end
      end

      it ":zone and :role are cleared" do
        MiqQueue.broadcast(queue_params)

        expect(queue_items.count).to eq(3)
        expect(queue_items.map(&:zone).all?(&:nil?)).to be_truthy
        expect(queue_items.map(&:role).all?(&:nil?)).to be_truthy
      end

      it "raises an error if :zone is passed" do
        queue_params[:zone] = other_zone
        expect { MiqQueue.broadcast(queue_params) }.to raise_error(ArgumentError)
      end

      it "raises an error if :role is passed" do
        queue_params[:role] = other_zone
        expect { MiqQueue.broadcast(queue_params) }.to raise_error(ArgumentError)
      end
    end
  end

  describe ".unqueue" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
    end

    # NOTE: default queue_name, state, zone
    it "should unqueue a message" do
      msg = MiqQueue.put(:class_name => 'MyClass', :method_name => 'method1')

      expect(MiqQueue.unqueue(:class_name => 'MyClass', :method_name => 'method1')).to eq(msg)
    end

    it "should unqueue a message to 'any' zone, other state (when included in a list), and other queue" do
      msg = MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :queue_name  => 'other_queue',
        :zone        => nil
      )
      msg.update(:state => MiqQueue::STATE_DEQUEUE)

      expect(
        MiqQueue.unqueue(
          :class_name  => 'MyClass',
          :method_name => 'method1',
          :queue_name  => 'other_queue',
          :zone        => 'myzone', # NOTE: not nil
          :state       => [MiqQueue::STATE_DEQUEUE, MiqQueue::STATE_READY]
        )
      ).to eq(msg)
    end

    it "should not unqueue a message from a different zone" do
      zone = FactoryBot.create(:zone)

      MiqQueue.put(:class_name => 'MyClass', :method_name => 'method1', :zone => zone.name)

      expect(MiqQueue.unqueue(:class_name => 'MyClass', :method_name => 'method1')).to be_nil
    end
  end

  # this is a private method, but there are too many permutations to properly test get/put
  context "#default_get_options" do
    before do
      allow(Zone).to receive_messages(:determine_queue_zone => "defaultzone")
    end

    it "should default the queue name" do
      expect(described_class.send(:default_get_options, {})).to include(:queue_name => MiqQueue::DEFAULT_QUEUE)
    end

    it "should default the queue name and others" do
      expect(
        described_class.send(:default_get_options, :other_key => "x")
      ).to include(
        :queue_name => MiqQueue::DEFAULT_QUEUE,
        :other_key  => "x",
        :state      => MiqQueue::STATE_READY,
        :zone       => "defaultzone"
      )
    end

    it "should override the queue name" do
      expect(
        described_class.send(:default_get_options, :queue_name => "non_generic")
      ).to include(:queue_name => "non_generic")
    end
  end

  # this is a private method, but easier to just test directly
  it "should expand keys, not expand non specified keys, and not add missing keys" do
    expect(described_class.send(:optional_values, {
                                  :not_expanded => "notexp",
                                  :expanded     => "exp"
                                }, [:expanded, :missing])).to eq(
                                  :not_expanded => "notexp",
                                  :expanded     => [nil, "exp"]
                                )
  end

  context "#delivered" do
    it "destroys a stale object" do
      q = MiqQueue.create!(:state => 'ready')
      MiqQueue.find(q.id).tap { |q2| q2.state = 'dequeue' }.save # update doesn't expose the issue

      q.delivered('warn', nil, nil)

      expect(MiqQueue.where(:id => q.id).count).to eq(0)
    end
  end

  context "validates that the zone exists in the current region" do
    it "with a matching region" do
      zone = FactoryBot.create(:zone)
      expect(MiqQueue.create!(:state => "ready", :zone => zone.name)).to be_kind_of(MiqQueue)
    end

    it "without a matching region" do
      expect { MiqQueue.create!(:state => "ready", :zone => "Missing Zone") }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "without a zone" do
      expect(MiqQueue.create!(:state => "ready")).to be_kind_of(MiqQueue)
    end
  end

  context ".submit_job", :submit_job do
    let(:ems) { FactoryBot.create(:ems_vmware) }
    let(:vm) { FactoryBot.create(:vm_vmware, :ext_management_system => ems) }
    let(:options) { {:method_name => 'enable', :class_name => vm.class.name, :instance_id => vm.id, :affinity => ems} }

    it "sets options to expected values for an ems_operations service" do
      queue = MiqQueue.submit_job(options.merge(:service => 'ems_operations'))

      expect(queue).to have_attributes(
        :class_name  => vm.class.name,
        :method_name => options[:method_name],
        :role        => 'ems_operations',
        :queue_name  => ems.queue_name_for_ems_operations,
        :zone        => ems.my_zone,
        :args        => []
      )
    end
  end

  describe ".messaging_client_options" do
    context "with ENV" do
      let(:env_vars) { ENV.to_h.merge("MESSAGING_HOSTNAME" => "server.example.com", "MESSAGING_PORT" => "9092", "MESSAGING_USERNAME" => "admin") }

      context "prefers settings from ENV when they exist" do
        it "with clear text password" do
          stub_const("ENV", env_vars.to_h.merge("MESSAGING_PASSWORD" => "password"))

          expect(YAML).not_to receive(:load_file).with(MiqQueue::MESSAGING_CONFIG_FILE)

          expect(MiqQueue.send(:messaging_client_options)).to eq(
            :encoding => "json",
            :host     => "server.example.com",
            :password => "password",
            :port     => 9092,
            :protocol => nil,
            :username => "admin"
          )
        end

        it "with encrypted password" do
          stub_const("ENV", env_vars.to_h.merge("MESSAGING_PASSWORD" => ManageIQ::Password.encrypt("password")))

          expect(YAML).not_to receive(:load_file).with(MiqQueue::MESSAGING_CONFIG_FILE)

          expect(ENV["MESSAGING_PASSWORD"]).to be_encrypted
          expect(MiqQueue.send(:messaging_client_options)).to eq(
            :encoding => "json",
            :host     => "server.example.com",
            :password => "password",
            :port     => 9092,
            :protocol => nil,
            :username => "admin"
          )
        end
      end

      it "prefers settings from file if any ENV vars are missing" do
        stub_const("ENV", env_vars) # No password

        allow(YAML).to receive(:load_file).and_call_original
        expect(YAML).to receive(:load_file).with(MiqQueue::MESSAGING_CONFIG_FILE).and_return("test" => {"hostname" => "kafka.example.com", "port" => 9092, "username" => "user", "password" => "password"})

        expect(MiqQueue.send(:messaging_client_options)).to eq(
          :encoding => "json",
          :host     => "kafka.example.com",
          :password => "password",
          :port     => 9092,
          :protocol => nil,
          :username => "user"
        )
      end
    end

    context "prefers settings from file when ENV vars are missing" do
      it "with clear text password" do
        allow(YAML).to receive(:load_file).and_call_original
        expect(YAML).to receive(:load_file).with(MiqQueue::MESSAGING_CONFIG_FILE).and_return("test" => {"hostname" => "kafka.example.com", "port" => 9092, "username" => "user", "password" => "password"})

        expect(MiqQueue.send(:messaging_client_options)).to eq(
          :encoding => "json",
          :host     => "kafka.example.com",
          :password => "password",
          :port     => 9092,
          :protocol => nil,
          :username => "user"
        )
      end

      it "with encrypted password" do
        allow(YAML).to receive(:load_file).and_call_original
        expect(YAML).to receive(:load_file).with(MiqQueue::MESSAGING_CONFIG_FILE).and_return("test" => {"hostname" => "kafka.example.com", "port" => 9092, "username" => "user", "password" => ManageIQ::Password.encrypt("password")})

        expect(MiqQueue.send(:messaging_client_options)).to eq(
          :encoding => "json",
          :host     => "kafka.example.com",
          :password => "password",
          :port     => 9092,
          :protocol => nil,
          :username => "user"
        )
      end
    end
  end
end
