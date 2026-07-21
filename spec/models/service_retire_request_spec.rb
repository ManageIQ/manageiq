RSpec.describe ServiceRetireRequest do
  let!(:service) { FactoryBot.create(:service) }

  describe ".request_task_class_from" do
    it "returns ServiceRetireTask (no EMS support)" do
      attribs = {'options' => {:src_ids => [service.id]}}
      expect(described_class.request_task_class_from(attribs)).to eq(ServiceRetireTask)
    end

    context "with src_ids option" do
      it "handles src_ids option" do
        attribs = {'options' => {:src_ids => [service.id]}}
        expect { described_class.request_task_class_from(attribs) }.not_to raise_error
        expect(described_class.request_task_class_from(attribs)).to eq(ServiceRetireTask)
      end
    end

    context "when service is not found" do
      it "raises MiqRetireRequestError" do
        attribs = {'options' => {:src_ids => [-1]}}
        expect { described_class.request_task_class_from(attribs) }
          .to raise_error(MiqException::MiqRetireRequestError, /Unable to find Service/)
      end
    end
  end

  describe ".new_request_task" do
    it "creates a task with the correct class" do
      attribs = {
        'options'     => {:src_ids => [service.id]},
        'source_id'   => service.id,
        'source_type' => 'Service'
      }

      task = described_class.new_request_task(attribs)
      expect(task).to be_a(ServiceRetireTask)
      expect(task.source_id).to eq(service.id)
    end
  end
end
