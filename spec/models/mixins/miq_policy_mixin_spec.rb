describe MiqPolicyMixin do
  let(:policy) { FactoryBot.create(:miq_policy) }
  let(:policy_set) { FactoryBot.create(:miq_policy_set).tap { |ps| ps.add_member(policy) } }
  subject { TestModel.create }

  before do
    class TestModel < ApplicationRecord
      self.table_name = "hosts" # any table really
      acts_as_miq_taggable
      include MiqPolicyMixin
    end
  end

  after do
    Object.send(:remove_const, :TestModel)
  end

  include_examples "MiqPolicyMixin"

  describe "task handoff" do
    let(:task) { FactoryBot.create(:miq_task) }
    let(:record) { TestModel.create }
    let(:shape_a) { {:class_name => "MiqTask", :instance_id => task.id, :method_name => :queue_callback, :args => ["Finished"]} }
    let(:shape_b) { {:class_name => "TestModel", :instance_id => record.id, :method_name => :powerops_callback, :args => [task.id]} }
    let(:callback) { shape_a }
    let(:msg_options) { {} }
    let(:msg) do
      MiqQueue.create!({:class_name => "TestModel", :instance_id => record.id, :method_name => "perform", :miq_task_id => task.id,
                        :miq_callback => callback, :state => "ready", :zone => nil, :role => nil}.merge(msg_options))
    end

    def prevented_workspace(message, prevented: true)
      event = double("event_stream", :attributes => {"full_data" => {:policy => {:prevented => prevented}}, "message" => message})
      MiqAeEngine::MiqAeWorkspaceRuntime.new.tap do |ws|
        allow(ws).to receive(:get_obj_from_path).with("/").and_return("event_stream" => event)
      end
    end

    before do
      EvmSpecHelper.local_miq_server
      allow(MiqEvent).to receive(:raise_evm_event).and_return(double("event"))
    end

    after { $_miq_worker_current_msg = nil }

    def handoff_callback
      captured = nil
      allow(MiqEvent).to receive(:raise_evm_event) do |_target, _event, _inputs, options|
        captured = options[:miq_callback]
        double("event")
      end
      $_miq_worker_current_msg = msg
      record.policy_prevent_with_task_handoff(:perform) { |cb| MiqEvent.raise_evm_event(record, :evt, {}, :miq_callback => cb) }
      captured
    end

    [:shape_a, :shape_b].each do |shape|
      context "with a #{shape} message" do
        let(:callback) { send(shape) }

        it "takes over the task" do
          cb = handoff_callback
          expect(cb).to include(:method_name => :check_policy_prevent_task_callback, :args => [task.id, :perform])
          expect(msg.miq_callback).to be_blank
          expect(msg.changed).not_to include("miq_callback")
        end

        it "finishes the task with the policy message when prevented" do
          cb = handoff_callback
          expect(record).not_to receive(:perform)
          ws = prevented_workspace("Policy says no")
          record.check_policy_prevent_task_callback(*cb[:args], "ok", "msg", ws)

          expect(ws).to have_received(:get_obj_from_path).with("/")
          expect([task.reload.state, task.status, task.message]).to eq(["Finished", "Error", "Policy says no"])
        end
      end
    end

    context "task handling of the action" do
      before do
        TestModel.class_eval do
          def perform(*_args, **_kwargs)
          end
        end
      end

      it "runs the action and finishes the task" do
        expect(record).to receive(:perform).with("a", :b => 1).once
        record.check_policy_prevent_task_callback(task.id, :perform, "a", {:b => 1}, "ok", "msg", prevented_workspace(nil, :prevented => false))

        expect([task.reload.state, task.status]).to eq(%w[Finished Ok])
      end

      it "finishes the task with the error and re-raises when the action raises" do
        allow(record).to receive(:perform).and_raise("boom")
        expect do
          record.check_policy_prevent_task_callback(task.id, :perform, "ok", "msg", prevented_workspace(nil, :prevented => false))
        end.to raise_error("boom")

        expect([task.reload.state, task.status, task.message]).to eq(%w[Finished Error boom])
      end

      it "runs the action when the task is gone" do
        expect(record).to receive(:perform).once
        record.check_policy_prevent_task_callback(-1, :perform, "ok", "msg", prevented_workspace(nil, :prevented => false))
      end

      context "when the action queues a message and accepts miq_task_id" do
        before do
          TestModel.class_eval do
            attr_accessor :queue_nothing, :queue_options

            def perform_queue(miq_task_id: nil)
              return if queue_nothing

              MiqQueue.put({:class_name => self.class.name, :instance_id => id, :method_name => "perform"}
                .merge(policy_prevent_task_queue_options(miq_task_id))
                .merge(queue_options.to_h))
            end
          end
        end

        it "hands the task to the queued message" do
          record.check_policy_prevent_task_callback(task.id, :perform_queue, "ok", "msg", prevented_workspace(nil, :prevented => false))

          msg = MiqQueue.find_by(:method_name => "perform")
          expect(msg.miq_task_id).to eq(task.id)
          expect(msg.miq_callback).to include(:class_name => "MiqTask", :method_name => :queue_callback, :instance_id => task.id)
          expect(task.reload.state).not_to eq("Finished")
        end

        it "finishes the task with an error when no message was created" do
          record.queue_nothing = true
          record.check_policy_prevent_task_callback(task.id, :perform_queue, "ok", "msg", prevented_workspace(nil, :prevented => false))

          expect([task.reload.state, task.status, task.message]).to eq(["Finished", "Error", "queue message not created"])
        end

        it "finishes the task when the queued message tracks another task" do
          record.queue_options = {:miq_task_id => 0, :miq_callback => nil}
          record.check_policy_prevent_task_callback(task.id, :perform_queue, "ok", "msg", prevented_workspace(nil, :prevented => false))

          expect(MiqQueue.find_by(:method_name => "perform").miq_task_id).to eq(0)
          expect([task.reload.state, task.status]).to eq(%w[Finished Ok])
        end
      end

      it "builds no task queue options without a task" do
        expect(record.policy_prevent_task_queue_options(nil)).to eq({})
        expect(record.policy_prevent_task_queue_options(task.id)).to include(:miq_task_id => task.id)
      end

      it "keeps the existing callback behavior when prevented" do
        expect(record).not_to receive(:perform)
        ws = prevented_workspace("Policy says no")
        expect { record.check_policy_prevent_callback(:perform, "ok", "msg", ws) }.not_to raise_error
        expect(ws).to have_received(:get_obj_from_path).with("/")
      end

      it "keeps the existing callback behavior when not prevented" do
        expect(record).to receive(:perform).once
        record.check_policy_prevent_callback(:perform, "ok", "msg", prevented_workspace(nil, :prevented => false))
      end
    end

    context "when the message is not detected as tracking a task" do
      def expect_untouched
        $_miq_worker_current_msg = msg
        original = msg.miq_callback
        cb = nil
        record.policy_prevent_with_task_handoff(:perform) do |c|
          cb = c
          double("event")
        end

        expect(cb[:method_name]).to eq(:check_policy_prevent_callback)
        expect(msg.miq_callback).to eq(original)
      end

      it "without a current message" do
        $_miq_worker_current_msg = nil
        expect(record.policy_prevent_with_task_handoff(:perform) { |c| c }).to eq(record.prevent_callback_settings(:perform))
      end

      context "without a task" do
        let(:msg_options) { {:miq_task_id => nil} }
        it { expect_untouched }
      end

      context "with an unrelated callback" do
        let(:callback) { shape_a.merge(:method_name => :queue_callback_on_exceptions) }
        it { expect_untouched }
      end

      context "with another record's instance id" do
        let(:msg_options) { {:instance_id => -1} }
        it { expect_untouched }
      end

      context "with a class the record is not an instance of" do
        let(:msg_options) { {:class_name => "Host"} }
        it { expect_untouched }
      end

      context "with a powerops callback for another task" do
        let(:callback) { shape_b.merge(:args => [task.id + 1]) }
        it { expect_untouched }
      end
    end

    context "when the event is not raised" do
      let(:callback) { shape_a }

      it "keeps the message callback" do
        $_miq_worker_current_msg = msg
        record.policy_prevent_with_task_handoff(:perform) { nil }

        expect(msg.miq_callback).to eq(shape_a)
      end
    end

    context "when the event is raised but not queued" do
      it "finishes the task with an error and clears the callback" do
        $_miq_worker_current_msg = msg
        allow(record).to receive(:policy_event_queueable?).and_return(false)
        record.policy_prevent_with_task_handoff(:perform) { double("event") }

        expect([task.reload.state, task.status]).to eq(%w[Finished Error])
        expect(msg.miq_callback).to be_blank
      end
    end
  end
end
