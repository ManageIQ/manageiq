describe MiqQueue do
  specify { expect(FactoryGirl.build(:miq_queue)).to be_valid }

  context "#deliver" do
    before do
      _, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone
    end

    it "works with deliver_on" do
      deliver_on = Time.now.utc + 1.minute
      allow(Storage).to receive(:foobar).and_raise(MiqException::MiqQueueRetryLater.new(:deliver_on => deliver_on))
      msg = FactoryGirl.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :handler => @miq_server, :class_name => 'Storage', :method_name => 'foobar')
      status, message, result = msg.deliver

      expect(status).to eq(MiqQueue::STATUS_RETRY)
      expect(msg.state).to eq(MiqQueue::STATE_READY)
      expect(msg.handler).to    be_nil
      expect(msg.deliver_on).to eq(deliver_on)

      allow(Storage).to receive(:foobar).and_raise(MiqException::MiqQueueRetryLater.new)
      msg.state   = MiqQueue::STATE_DEQUEUE
      msg.handler = @miq_server
      status, message, result = msg.deliver

      expect(status).to eq(MiqQueue::STATUS_RETRY)
      expect(msg.state).to eq(MiqQueue::STATE_READY)
      expect(msg.handler).to be_nil
    end

    it "works with expires_on" do
      allow(MiqServer).to receive(:foobar).and_return(0)

      expires_on = 1.minute.from_now.utc
      msg = FactoryGirl.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :handler => @miq_server, :class_name => 'MiqServer', :method_name => 'foobar', :expires_on => expires_on)
      status, message, result = msg.deliver
      expect(status).to eq(MiqQueue::STATUS_OK)

      expires_on = 1.minute.ago.utc
      msg = FactoryGirl.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :handler => @miq_server, :class_name => 'MiqServer', :method_name => 'foobar', :expires_on => expires_on)
      status, message, result = msg.deliver
      expect(status).to eq(MiqQueue::STATUS_EXPIRED)
    end

    it "sets last_exception on raised Exception" do
      allow(MiqServer).to receive(:foobar).and_raise(StandardError)
      msg = FactoryGirl.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :handler => @miq_server, :class_name => 'MiqServer', :method_name => 'foobar')
      status, message, result = msg.deliver
      expect(status).to eq(MiqQueue::STATUS_ERROR)
      expect(msg.last_exception).to be_kind_of(Exception)
    end
  end

  context "With messages left in dequeue at startup," do
    before do
      _, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone

      @other_miq_server = FactoryGirl.create(:miq_server, :zone => @miq_server.zone)

      @worker       = FactoryGirl.create(:miq_ems_refresh_worker, :miq_server_id => @miq_server.id)
      @other_worker = FactoryGirl.create(:miq_ems_refresh_worker, :miq_server_id => @other_miq_server.id)
    end

    context "where worker has a message in dequeue" do
      before do
        @msg = FactoryGirl.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :handler => @worker)
      end

      it "will destroy the message when it times out" do
        @msg.update_attributes(:msg_timeout => 1.minutes)
        begin
          Timecop.travel 10.minute
          expect($log).to receive(:warn)
          expect(@msg).to receive(:destroy)
          @msg.check_for_timeout
        ensure
          Timecop.return
        end
      end

      it "should cleanup message on startup" do
        MiqQueue.atStartup

        @msg.reload
        expect(@msg.state).to eq(MiqQueue::STATE_ERROR)
      end
    end

    context "where worker on other server has a message in dequeue" do
      before do
        @msg = FactoryGirl.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :handler => @other_worker)
      end

      it "should not cleanup message on startup" do
        MiqQueue.atStartup

        @msg.reload
        expect(@msg.state).to eq(MiqQueue::STATE_DEQUEUE)
      end
    end

    context "message in dequeue without a worker" do
      before do
        @msg = FactoryGirl.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE)
      end

      it "should cleanup message on startup" do
        MiqQueue.atStartup

        @msg.reload
        expect(@msg.state).to eq(MiqQueue::STATE_ERROR)
      end
    end
  end

  it "should validate formatting of message for logging" do
    # Add various key/value combos as needs arise...
    message_parms = [
      {:target_id    => nil,
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
      }
    ]

    message_parms.each do |mparms|
      msg = FactoryGirl.create(:miq_queue)
      mparms.each { |k, v| msg.send("#{k}=", v) }
      expect(MiqQueue.format_short_log_msg(msg)).to eq("Message id: [#{msg.id}]")
      expect(MiqQueue.format_full_log_msg(msg)).to eq("Message id: [#{msg.id}], #{msg.handler_type} id: [#{msg.handler_id}], Zone: [#{msg.zone}], Role: [#{msg.role}], Server: [#{msg.server_guid}], Ident: [#{msg.queue_name}], Target id: [#{msg.target_id}], Instance id: [#{msg.instance_id}], Task id: [#{msg.task_id}], Command: [#{msg.class_name}.#{msg.method_name}], Timeout: [#{msg.msg_timeout}], Priority: [#{msg.priority}], State: [#{msg.state}], Deliver On: [#{msg.deliver_on}], Data: [#{msg.data.nil? ? "" : "#{msg.data.length} bytes"}], Args: #{msg.args.inspect}")
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

    message_parms = [
      {:target_id    => nil,
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
      }
    ]

    message_parms.each do |mparms|
      msg = FactoryGirl.create(:miq_queue, mparms)
      expect(MiqQueue.format_short_log_msg(msg)).to eq("Message id: [#{msg.id}]")
      expect(MiqQueue.format_full_log_msg(msg)).to eq("Message id: [#{msg.id}], #{msg.handler_type} id: [#{msg.handler_id}], Zone: [#{msg.zone}], Role: [#{msg.role}], Server: [#{msg.server_guid}], Ident: [#{msg.queue_name}], Target id: [#{msg.target_id}], Instance id: [#{msg.instance_id}], Task id: [#{msg.task_id}], Command: [#{msg.class_name}.#{msg.method_name}], Timeout: [#{msg.msg_timeout}], Priority: [#{msg.priority}], State: [#{msg.state}], Deliver On: [#{msg.deliver_on}], Data: [#{msg.data.nil? ? "" : "#{msg.data.length} bytes"}], Args: #{args_cleaned_password.inspect}")
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
      @msg = FactoryGirl.create(:miq_queue, :zone => @zone.name, :role => "role1", :priority => 20, :created_on => @t1)
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

      @msg.update_attributes!(:state => 'error')
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

      @worker = FactoryGirl.create(:miq_ems_refresh_worker, :miq_server_id => @miq_server.id)
      @msg = FactoryGirl.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :task_id => "task123", :handler => @worker)
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
          :args        => "not_an_array",
        )

        msg_from_db = MiqQueue.find(msg.id)
        expect(msg_from_db.args).to eq(["not_an_array"])

        _, _, result = msg_from_db.deliver
        expect(result).to eq "not_an_array"
      ensure
        Object.send(:remove_const, :MiqQueueSpecNonArrayArgs)
      end
    end

    it "defaults args / miq_callback to [] / {}" do
      msg = MiqQueue.put(
        :class_name  => "Class1",
        :method_name => "Method1",
      )

      msg_from_db = MiqQueue.find(msg.id)
      expect(msg_from_db.args).to eq([])
      expect(msg_from_db.miq_callback).to eq({})
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

    it "should respect hash updates in put_unless_exists" do
      MiqQueue.put_unless_exists(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1, 2]
      ) do |_msg, find_options|
        find_options.merge(:args => [3, 3])
      end

      expect(MiqQueue.first.args).to eq([3, 3])
    end

    it "should not call into put_unless_exists" do
      MiqQueue.put_unless_exists(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1, 2]
      )
      MiqQueue.put_unless_exists(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1, 2]
      ) do |_msg, find_options|
        find_options.merge(:args => [3, 3])
      end

      expect(MiqQueue.first.args).to eq([1, 2])
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

    it "should use args param to find messages on the queue" do
      msg1 = MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1, 2],
        :task_id     => 'first_task'
      )
      msg2 = MiqQueue.put(
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

    it "should use args proc to find messages on the queue" do
      msg1 = MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1, 2],
        :task_id     => 'first_task'
      )
      msg2 = MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [3, 4],
        :task_id     => 'booring_task'
      )

      MiqQueue.put_or_update(
        :class_name    => 'MyClass',
        :method_name   => 'method1',
        :args_selector => ->(args) { args.kind_of?(Array) && args.last == 4 }
      ) do |_msg, params|
        params.merge(:task_id => 'fun_task')
      end

      expect(MiqQueue.get).to have_attributes(:args => [1, 2], :task_id => 'first_task')
      expect(MiqQueue.get).to have_attributes(:args => [3, 4], :task_id => 'fun_task')
      expect(MiqQueue.get).to eq(nil)
    end

    it "does not allow objects on the queue" do
      expect do
        MiqQueue.put(:class_name => 'MyClass', :method_name => 'method1', :args => [MiqServer.first])
      end.to raise_error(ArgumentError)
    end
  end

  describe ".unqueue" do
    before do
      EvmSpecHelper.create_guid_miq_server_zone
    end

    it "should unqueue a message" do
      msg = MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
      # NOTE: default queue_name, state, zone
      )
      expect(MiqQueue.unqueue(
               :class_name  => 'MyClass',
               :method_name => 'method1',
      # NOTE: default queue_name, state, zone
      )).to eq(msg)
    end

    it "should unqueue a message to 'any' zone, other state (when included in a list), and other queue" do
      msg = MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :queue_name  => 'other_queue',
        :zone        => nil,
      )
      msg.update_attributes(:state => MiqQueue::STATE_DEQUEUE)

      expect(MiqQueue.unqueue(
               :class_name  => 'MyClass',
               :method_name => 'method1',
               :queue_name  => 'other_queue',
               :zone        => 'myzone', # NOTE: not nil
               :state       => [MiqQueue::STATE_DEQUEUE, MiqQueue::STATE_READY],
      )).to eq(msg)
    end

    it "should not unqueue a message from a different zone" do
      MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :zone        => 'other_zone'
      )

      expect(MiqQueue.unqueue(
               :class_name  => 'MyClass',
               :method_name => 'method1',
      )).to be_nil
    end
  end

  # this is a private method, but there are too many permutations to properly test get/put
  context "#default_get_options" do
    before do
      allow(Zone).to receive_messages(:determine_queue_zone => "defaultzone")
    end

    it "should default the queue name" do
      expect(described_class.send(:default_get_options, {}
                                 )).to include(
                                   :queue_name => MiqQueue::DEFAULT_QUEUE
                                 )
    end

    it "should default the queue name and others" do
      expect(described_class.send(
               :default_get_options,
               :other_key => "x"
      )).to include(
        :queue_name => MiqQueue::DEFAULT_QUEUE,
        :other_key  => "x",
        :state      => MiqQueue::STATE_READY,
        :zone       => "defaultzone"
      )
    end

    it "should override the queue name" do
      expect(described_class.send(
               :default_get_options,
               :queue_name => "non_generic"
      )).to include(
        :queue_name => "non_generic"
      )
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
      MiqQueue.find(q.id).tap { |q2| q2.state = 'dequeue' }.save # update_attributes doesn't expose the issue

      q.delivered('warn', nil, nil)

      expect(MiqQueue.where(:id => q.id).count).to eq(0)
    end
  end
end
