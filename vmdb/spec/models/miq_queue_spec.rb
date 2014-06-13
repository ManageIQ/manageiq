require "spec_helper"

describe MiqQueue do
  specify { FactoryGirl.build(:miq_queue).should be_valid }

  context "#deliver" do
    before(:each) do
      @guid, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone
    end

    it "works with deliver_on" do
      deliver_on = Time.now.utc + 1.minute
      Storage.stub(:foobar).and_raise(MiqException::MiqQueueRetryLater.new( { :deliver_on => deliver_on } ))
      msg = FactoryGirl.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :handler => @miq_server, :class_name => 'Storage', :method_name => 'foobar')
      status, message, result = msg.deliver

      status.should         == MiqQueue::STATUS_RETRY
      msg.state.should      == MiqQueue::STATE_READY
      msg.handler.should    be_nil
      msg.deliver_on.should == deliver_on

      Storage.stub(:foobar).and_raise(MiqException::MiqQueueRetryLater.new)
      msg.state   = MiqQueue::STATE_DEQUEUE
      msg.handler = @miq_server
      status, message, result = msg.deliver

      status.should      == MiqQueue::STATUS_RETRY
      msg.state.should   == MiqQueue::STATE_READY
      msg.handler.should be_nil
    end

    it "works with expires_on" do
      MiqServer.stub(:foobar).and_return(0)

      expires_on = 1.minute.from_now.utc
      msg = FactoryGirl.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :handler => @miq_server, :class_name => 'MiqServer', :method_name => 'foobar', :expires_on => expires_on)
      status, message, result = msg.deliver
      status.should == MiqQueue::STATUS_OK

      expires_on = 1.minute.ago.utc
      msg = FactoryGirl.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :handler => @miq_server, :class_name => 'MiqServer', :method_name => 'foobar', :expires_on => expires_on)
      status, message, result = msg.deliver
      status.should == MiqQueue::STATUS_EXPIRED
    end

    it "sets last_exception on raised Exception" do
      MiqServer.stub(:foobar).and_raise(Exception)
      msg = FactoryGirl.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :handler => @miq_server, :class_name => 'MiqServer', :method_name => 'foobar')
      status, message, result = msg.deliver
      status.should == MiqQueue::STATUS_ERROR
      msg.last_exception.should be_kind_of(Exception)
    end
  end

  context "With messages left in dequeue at startup," do
    before(:each) do
      @guid, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone

      @other_miq_server = FactoryGirl.create(:miq_server, :guid => MiqUUID.new_guid, :zone => @zone)

      @worker       = FactoryGirl.create(:miq_ems_refresh_worker, :miq_server_id => @miq_server.id)
      @other_worker = FactoryGirl.create(:miq_ems_refresh_worker, :miq_server_id => @other_miq_server.id)
    end

    context "where worker has a message in dequeue" do
      before(:each) do
        @msg = FactoryGirl.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :handler => @worker)
      end

      it "will destroy the message when it times out" do
        @msg.update_attributes(:msg_timeout => 1.minutes)
        begin
          Timecop.travel 10.minute
          $log.should_receive(:warn)
          @msg.should_receive(:destroy)
          @msg.check_for_timeout
        ensure
          Timecop.return
        end
      end

      it "should cleanup message on startup" do
        MiqQueue.atStartup

        @msg.reload
        @msg.state.should == MiqQueue::STATE_ERROR
      end
    end

    context "where worker on other server has a message in dequeue" do
      before(:each) do
        @msg = FactoryGirl.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :handler => @other_worker)
      end

      it "should not cleanup message on startup" do
        MiqQueue.atStartup

        @msg.reload
        @msg.state.should == MiqQueue::STATE_DEQUEUE
      end
    end

    context "message in dequeue without a worker" do
      before(:each) do
        @msg = FactoryGirl.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE)
      end

      it "should cleanup message on startup" do
        MiqQueue.atStartup

        @msg.reload
        @msg.state.should == MiqQueue::STATE_ERROR
      end
    end

  end

  it "should validate formatting of message for logging" do
    # Add various key/value combos as needs arise...
    message_parms = [
      { :target_id => nil,
        :priority => 20,
        :method_name => 'perf_rollup_gap',
        :state => 'ready',
        :task_id => nil,
        :queue_name => 'ems_metrics_processor',
        :class_name => 'Metric::Rollup',
        :instance_id => nil,
        :args => '',
        :zone => 'default',
        :role => 'ems_metrics_processor',
        :server_guid => nil,
        :msg_timeout => 600,
        :handler_type => nil
      }
    ]

    message_parms.each do |mparms|
      msg = FactoryGirl.create(:miq_queue)
      mparms.each { |k, v| msg.send("#{k}=", v) }
      MiqQueue.format_short_log_msg(msg).should == "Message id: [#{msg.id}]"
      MiqQueue.format_full_log_msg(msg).should  == "Message id: [#{msg.id}], #{msg.handler_type} id: [#{msg.handler_id}], Zone: [#{msg.zone}], Role: [#{msg.role}], Server: [#{msg.server_guid}], Ident: [#{msg.queue_name}], Target id: [#{msg.target_id}], Instance id: [#{msg.instance_id}], Task id: [#{msg.task_id}], Command: [#{msg.class_name}.#{msg.method_name}], Timeout: [#{msg.msg_timeout}], Priority: [#{msg.priority}], State: [#{msg.state}], Deliver On: [#{msg.deliver_on}], Data: [#{msg.data.nil? ? "" : "#{msg.data.length} bytes"}], Args: #{msg.args.inspect}"
    end
  end

  it "should validate formatting of message with encrypted password in args for logging" do
    
    # Some reasonably accurate test data.
    args_test = [
      "[datastore1] test-cfme-vddk2/test-cfme-vddk2.vmx",
      "---ems: ems: :address: 16.16.52.50 :hostname: 16.16.52.50 :ipaddress: 16.16.52.50 :username: administrator :password: v2:{lalala} :class_name: EmsVmware host: :address: 16.16.52.50 :hostname: myhost.redhat.com :ipaddress: 16.16.52.50 :username: root :password: v1:{lalala} :class_name: HostVmwareEsx connect_to: host snapshot: use_existing: false"
    ]

    args_cleaned_password = [
      "[datastore1] test-cfme-vddk2/test-cfme-vddk2.vmx",
      "---ems: ems: :address: 16.16.52.50 :hostname: 16.16.52.50 :ipaddress: 16.16.52.50 :username: administrator :password: ******** :class_name: EmsVmware host: :address: 16.16.52.50 :hostname: myhost.redhat.com :ipaddress: 16.16.52.50 :username: root :password: ******** :class_name: HostVmwareEsx connect_to: host snapshot: use_existing: false"
    ]

    message_parms = [
      { :target_id => nil,
        :priority => 20,
        :method_name => 'perf_rollup_gap',
        :state => 'ready',
        :task_id => nil,
        :queue_name => 'ems_metrics_processor',
        :class_name => 'Metric::Rollup',
        :instance_id => nil,
        :args => args_test,
        :zone => 'default',
        :role => 'ems_metrics_processor',
        :server_guid => nil,
        :msg_timeout => 600,
        :handler_type => nil
      }
    ]

    message_parms.each do |mparms|
      msg = FactoryGirl.create(:miq_queue, mparms)
      MiqQueue.format_short_log_msg(msg).should == "Message id: [#{msg.id}]"
      MiqQueue.format_full_log_msg(msg).should  == "Message id: [#{msg.id}], #{msg.handler_type} id: [#{msg.handler_id}], Zone: [#{msg.zone}], Role: [#{msg.role}], Server: [#{msg.server_guid}], Ident: [#{msg.queue_name}], Target id: [#{msg.target_id}], Instance id: [#{msg.instance_id}], Task id: [#{msg.task_id}], Command: [#{msg.class_name}.#{msg.method_name}], Timeout: [#{msg.msg_timeout}], Priority: [#{msg.priority}], State: [#{msg.state}], Deliver On: [#{msg.deliver_on}], Data: [#{msg.data.nil? ? "" : "#{msg.data.length} bytes"}], Args: #{args_cleaned_password.inspect}"
    end
  end

  context "executing priority" do
    it "should return adjusted value" do
      MiqQueue.priority(:max).should    == MiqQueue::MAX_PRIORITY
      MiqQueue.priority(:high).should   == MiqQueue::HIGH_PRIORITY
      MiqQueue.priority(:normal).should == MiqQueue::NORMAL_PRIORITY
      MiqQueue.priority(:low).should    == MiqQueue::LOW_PRIORITY
      MiqQueue.priority(:min).should    == MiqQueue::MIN_PRIORITY

      MiqQueue.priority(5000).should    == MiqQueue::MIN_PRIORITY
      MiqQueue.priority(-5000).should   == MiqQueue::MAX_PRIORITY
      MiqQueue.priority(100).should     == 100

      lambda { MiqQueue.priority(:other)        }.should raise_error(ArgumentError)
      lambda { MiqQueue.priority(:high, :other) }.should raise_error(ArgumentError)

      MiqQueue.priority(:normal, :higher, 10).should == MiqQueue::NORMAL_PRIORITY - 10
      MiqQueue.priority(:normal, :lower,  10).should == MiqQueue::NORMAL_PRIORITY + 10

      MiqQueue.priority(:min, :lower,  1).should == MiqQueue::MIN_PRIORITY
      MiqQueue.priority(:max, :higher, 1).should == MiqQueue::MAX_PRIORITY
    end

    it "should validate comparisons" do
      MiqQueue.higher_priority( MiqQueue::MIN_PRIORITY, MiqQueue::MAX_PRIORITY).should == MiqQueue::MAX_PRIORITY
      MiqQueue.higher_priority( MiqQueue::MAX_PRIORITY, MiqQueue::MIN_PRIORITY).should == MiqQueue::MAX_PRIORITY
      MiqQueue.higher_priority?(MiqQueue::MIN_PRIORITY, MiqQueue::MAX_PRIORITY).should be_false
      MiqQueue.higher_priority?(MiqQueue::MAX_PRIORITY, MiqQueue::MIN_PRIORITY).should be_true

      MiqQueue.lower_priority( MiqQueue::MIN_PRIORITY,  MiqQueue::MAX_PRIORITY).should  == MiqQueue::MIN_PRIORITY
      MiqQueue.lower_priority( MiqQueue::MAX_PRIORITY,  MiqQueue::MIN_PRIORITY).should  == MiqQueue::MIN_PRIORITY
      MiqQueue.lower_priority?(MiqQueue::MIN_PRIORITY,  MiqQueue::MAX_PRIORITY).should be_true
      MiqQueue.lower_priority?(MiqQueue::MAX_PRIORITY,  MiqQueue::MIN_PRIORITY).should be_false
    end

  end

  context "miq_queue with messages" do
    before(:each) do
      @guid, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone

      @t1 = Time.parse("Wed Apr 20 00:15:00 UTC 2011")
      @t2 = Time.parse("Mon Apr 25 10:30:15 UTC 2011")
      @t3 = Time.parse("Thu Apr 28 20:45:30 UTC 2011")

      Timecop.freeze(Time.parse("Thu Apr 30 12:45:00 UTC 2011"))

      @msg = []
      @msg << FactoryGirl.create(:miq_queue, :zone => @zone.name, :state => MiqQueue::STATE_DEQUEUE,  :role => "role1", :priority => 20, :created_on => @t1)
      @msg << FactoryGirl.create(:miq_queue, :zone => @zone.name, :state => MiqQueue::STATE_DEQUEUE,  :role => "role1", :priority => 20, :created_on => @t1)
      @msg << FactoryGirl.create(:miq_queue, :zone => @zone.name, :state => MiqQueue::STATE_DEQUEUE,  :role => "role2", :priority => 20, :created_on => @t1)
      @msg << FactoryGirl.create(:miq_queue, :zone => @zone.name, :state => MiqQueue::STATE_READY,    :role => "role1", :priority => 20, :created_on => @t1)
      @msg << FactoryGirl.create(:miq_queue, :zone => @zone.name, :state => MiqQueue::STATE_READY,    :role => "role1", :priority => 20, :created_on => @t2)
      @msg << FactoryGirl.create(:miq_queue, :zone => @zone.name, :state => MiqQueue::STATE_READY,    :role => "role1", :priority => 20, :created_on => @t3)
      @msg << FactoryGirl.create(:miq_queue, :zone => "east",     :state => MiqQueue::STATE_DEQUEUE,  :role => "role1", :priority => 20, :created_on => @t3)
      @msg << FactoryGirl.create(:miq_queue, :zone => "west",     :state => MiqQueue::STATE_READY,    :role => "role3", :priority => 20, :created_on => @t3)
      @msg << FactoryGirl.create(:miq_queue, :zone => @zone.name, :state => MiqQueue::STATE_ERROR,    :role => "role1", :priority => 20, :created_on => @t2)
      @msg << FactoryGirl.create(:miq_queue, :zone => @zone.name, :state => MiqQueue::STATE_WARN,     :role => "role3", :priority => 20, :created_on => @t2)
      @msg << FactoryGirl.create(:miq_queue, :zone => "east",     :state => MiqQueue::STATE_DEQUEUE,  :role => "role1", :priority => 20, :created_on => Time.now.utc)
      @msg << FactoryGirl.create(:miq_queue, :zone => "west",     :state => MiqQueue::STATE_ERROR,    :role => "role2", :priority => 20, :created_on => Time.now.utc)
    end

    after do
      Timecop.return
    end

    it "should calculate wait times" do
      cor = MiqQueue.wait_times_by_role
      cor.should == {
        "role1" => { :next => (Time.now - @t3), :last => (Time.now - @t1) },
        "role3" => { :next => (Time.now - @t3), :last => (Time.now - @t3) }
      }
    end
  end

  context "deliver to queue" do
    before(:each) do
      @guid, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone

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
        :msg_timeout => 60.minutes
      }

      @old_msg_id = @msg.id

      @new_msg = @msg.requeue(options)
      @new_msg_id = @new_msg.id

      @msg.id.should_not == @msg.requeue(options).id
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

      @msg.requeue(options).id.should be > @msg.id
    end

    it "should requeue a message" do
      hash_value = "test_string_2_05312011"
      @msg.data = hash_value
      @msg.data.should == "test_string_2_05312011"
    end
  end

  context "worker" do
    before(:each) do
      @guid, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone

      @worker       = FactoryGirl.create(:miq_ems_refresh_worker, :miq_server_id => @miq_server.id)
      @msg = FactoryGirl.create(:miq_queue, :state => MiqQueue::STATE_DEQUEUE, :task_id => "task123", :handler => @worker)
    end

    it "should find a message by task id" do
      MiqQueue.get_worker("task123").should == @worker
    end

    it "should return worker handler" do
      @msg.get_worker.should == @worker
    end
  end

  context "#put" do
    before(:each) do
      @guid, @miq_server, @zone = EvmSpecHelper.create_guid_miq_server_zone
    end

    it "should put one message on queue" do
      msg = MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1,2]
      )

      expect(MiqQueue.get).to eq(msg)
      expect(MiqQueue.get).to eq(nil)
    end

    it "should put a unique message on the queue if method_name is different" do
      msg1 = MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1,2]
      )
      msg2 = MiqQueue.put_unless_exists(
        :class_name  => 'MyClass',
        :method_name => 'method2',
        :args        => [1,2]
      )

      expect(MiqQueue.get).to eq(msg1)
      expect(MiqQueue.get).to eq(msg2)
      expect(MiqQueue.get).to eq(nil)
    end

    it "should ignore state when putting a new message on the queue" do
      MiqQueue.put_unless_exists(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1,2]
      )

      expect(MiqQueue.first.state).to eq("ready")
    end

    it "should respect hash updates in put_unless_exists" do
      MiqQueue.put_unless_exists(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1,2]
      ) do |msg, find_options|
        find_options.merge(:args => [3,3])
      end

      expect(MiqQueue.first.args).to eq([3,3])
    end

    it "should not call into put_unless_exists" do
      MiqQueue.put_unless_exists(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1,2]
      )
      MiqQueue.put_unless_exists(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1,2]
      ) do |msg, find_options|
        find_options.merge(:args => [3,3])
      end

      expect(MiqQueue.first.args).to eq([1,2])
    end

    it "should not put duplicate messages on the queue" do
      msg1 = MiqQueue.put_unless_exists(
        :class_name  => 'MyClass',
        :method_name => 'method2',
        :args        => [1,2]
      )

      MiqQueue.put_unless_exists(
        :class_name  => 'MyClass',
        :method_name => 'method2',
        :args        => [1,2]
      )

      expect(MiqQueue.get).to eq(msg1)
      expect(MiqQueue.get).to eq(nil)
    end

    it "should use args param to find messages on the queue" do
      msg1 = MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1,2],
        :task_id     => 'first_task'
      )
      msg2 = MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [3,4],
        :task_id     => 'booring_task'
      )

      MiqQueue.put_or_update(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [3,4]
      ) do |msg, params|
        params.merge(:task_id => 'fun_task')
      end

      expect(MiqQueue.get).to have_attributes(:args => [1,2], :task_id => 'first_task')
      expect(MiqQueue.get).to have_attributes(:args => [3,4], :task_id => 'fun_task')
      expect(MiqQueue.get).to eq(nil)
    end

    it "should use args proc to find messages on the queue" do
      msg1 = MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [1,2],
        :task_id     => 'first_task'
      )
      msg2 = MiqQueue.put(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args        => [3,4],
        :task_id     => 'booring_task'
      )

      MiqQueue.put_or_update(
        :class_name  => 'MyClass',
        :method_name => 'method1',
        :args_selector => lambda {|args| args.kind_of?(Array) && args.last == 4 }
      ) do |msg, params|
        params.merge(:task_id => 'fun_task')
      end

      expect(MiqQueue.get).to have_attributes(:args => [1,2], :task_id => 'first_task')
      expect(MiqQueue.get).to have_attributes(:args => [3,4], :task_id => 'fun_task')
      expect(MiqQueue.get).to eq(nil)
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

  it "should warn if the data size is too big" do
    EvmSpecHelper.create_guid_miq_server_zone

    $log.should_receive(:warn).with(/miq_queue_spec.rb.*large payload/)
    MiqQueue.put(:class_name => 'MyClass', :method_name => 'method1', :data => 'a' * 600)
  end

  it "should not warn if the data size is small" do
    EvmSpecHelper.create_guid_miq_server_zone

    $log.should_not_receive(:warn).with(/large payload/)
    MiqQueue.put(:class_name => 'MyClass', :method_name => 'method1', :args => [1,2,3,4,5])
  end

  # this is a private method, but there are too many permutations to properly test get/put
  context "#default_get_options" do
    before do
      Zone.stub(:determine_queue_zone => "defaultzone")
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
end
