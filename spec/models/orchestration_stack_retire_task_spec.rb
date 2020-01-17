RSpec.describe OrchestrationStackRetireTask do
  let(:user) { FactoryBot.create(:user_with_group) }
  let(:orchestration_stack) { FactoryBot.create(:orchestration_stack) }
  let(:miq_request) { FactoryBot.create(:orchestration_stack_retire_request, :requester => user, :source => orchestration_stack) }
  let(:orchestration_stack_retire_task) { FactoryBot.create(:orchestration_stack_retire_task, :source => orchestration_stack, :miq_request => miq_request, :options => {:src_ids => [orchestration_stack.id] }) }
  let(:approver) { FactoryBot.create(:user_miq_request_approver) }

  it "should initialize properly" do
    expect(orchestration_stack_retire_task).to have_attributes(:state => "pending", :status => "Ok")
  end

  describe "deliver_to_automate" do
    before do
      MiqRegion.seed
      allow(MiqServer).to receive(:my_zone).and_return(Zone.seed.name)
      miq_request.approve(approver, "why not??")
    end

    it "updates the task state to pending" do
      expect(orchestration_stack_retire_task).to receive(:update_and_notify_parent).with(
        :state   => 'pending',
        :status  => 'Ok',
        :message => 'Automation Starting'
      )
      orchestration_stack_retire_task.deliver_to_automate
    end
  end

  describe "#self.get_description" do
    it "returns a description based upon the source service name" do
      expect(OrchestrationStackRetireTask.get_description(miq_request)).to eq("OrchestrationStack Retire for: #{orchestration_stack.name}")
    end
  end
end
