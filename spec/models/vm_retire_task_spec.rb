describe VmRetireTask do
  let(:user) { FactoryGirl.create(:user_with_group) }
  let(:vm) { FactoryGirl.create(:vm) }
  let(:miq_request) { FactoryGirl.create(:vm_retire_request, :requester => user) }
  let(:vm_retire_task) { FactoryGirl.create(:vm_retire_task, :source => vm, :miq_request => miq_request, :options => {:src_ids => [vm.id] }) }
  let(:approver) { FactoryGirl.create(:user_miq_request_approver) }

  it "should initialize properly" do
    expect(vm_retire_task).to have_attributes(:state => 'pending', :status => 'Ok')
  end

  describe "deliver_to_automate" do
    before do
      allow(MiqServer).to receive(:my_zone).and_return(Zone.seed.name)
      miq_request.approve(approver, "why not??")
    end

    it "updates the task state to pending" do
      expect(vm_retire_task).to receive(:update_and_notify_parent).with(
        :state   => 'pending',
        :status  => 'Ok',
        :message => 'Automation Starting'
      )
      vm_retire_task.deliver_to_automate
    end
  end
end
