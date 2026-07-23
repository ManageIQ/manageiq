RSpec.describe OrchestrationStackRetireRequest do
  let(:ems) { FactoryBot.create(:ems_openstack) }
  let(:stack) { FactoryBot.create(:orchestration_stack_openstack, :ext_management_system => ems) }

  describe ".request_task_class_from" do
    context "with default EMS" do
      it "returns OrchestrationStackRetireTask" do
        attribs = {'options' => {:src_ids => [stack.id]}}
        expect(described_class.request_task_class_from(attribs)).to eq(OrchestrationStackRetireTask)
      end
    end

    context "with custom EMS retire task class" do
      let(:custom_task_class) { Class.new(OrchestrationStackRetireTask) }

      before do
        allow(ems.class).to receive(:orchestration_stack_retire_task_class).and_return(custom_task_class)
      end

      it "returns the custom task class" do
        attribs = {'options' => {:src_ids => [stack.id]}}
        expect(described_class.request_task_class_from(attribs)).to eq(custom_task_class)
      end
    end

    context "with stack that has no EMS" do
      let(:stack_no_ems) { FactoryBot.create(:orchestration_stack, :ext_management_system => nil) }

      it "returns OrchestrationStackRetireTask" do
        attribs = {'options' => {:src_ids => [stack_no_ems.id]}}
        expect(described_class.request_task_class_from(attribs)).to eq(OrchestrationStackRetireTask)
      end
    end

    context "with src_ids option" do
      it "handles src_ids option" do
        attribs = {'options' => {:src_ids => [stack.id]}}
        expect { described_class.request_task_class_from(attribs) }.not_to raise_error
        expect(described_class.request_task_class_from(attribs)).to eq(OrchestrationStackRetireTask)
      end
    end

    context "when stack is not found" do
      it "raises MiqRetireRequestError" do
        attribs = {'options' => {:src_ids => [-1]}}
        expect { described_class.request_task_class_from(attribs) }
          .to raise_error(MiqException::MiqRetireRequestError, /Unable to find OrchestrationStack/)
      end
    end
  end

  describe ".new_request_task" do
    it "creates a task with the correct class" do
      attribs = {
        'options'     => {:src_ids => [stack.id]},
        'source_id'   => stack.id,
        'source_type' => 'OrchestrationStack'
      }

      task = described_class.new_request_task(attribs)
      expect(task).to be_a(OrchestrationStackRetireTask)
      expect(task.source_id).to eq(stack.id)
    end

    context "with custom EMS retire task class" do
      let(:custom_task_class) { Class.new(OrchestrationStackRetireTask) }

      before do
        allow(ems.class).to receive(:orchestration_stack_retire_task_class).and_return(custom_task_class)
      end

      it "creates a task with the custom class" do
        attribs = {
          'options'     => {:src_ids => [stack.id]},
          'source_id'   => stack.id,
          'source_type' => 'OrchestrationStack'
        }

        task = described_class.new_request_task(attribs)
        expect(task).to be_a(custom_task_class)
        expect(task.source_id).to eq(stack.id)
      end
    end
  end
end
