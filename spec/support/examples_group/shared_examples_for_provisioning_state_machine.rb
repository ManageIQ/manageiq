shared_examples_for "common rhev state machine methods" do
  it "#customize_destination" do
    allow(@task).to receive(:get_provider_destination).and_return(nil)
    allow(@task).to receive(:update_and_notify_parent)

    expect(@task).to receive(:configure_container)

    @task.customize_destination
  end
end

shared_examples_for "polling destination power status in provider" do
  it "#poll_destination_powered_off_in_provider" do
    expect(@task).to receive(:powered_off_in_provider?).and_return(true)
    expect(@task).to receive(:requeue_phase)

    @task.poll_destination_powered_off_in_provider
  end

  context "#poll_destination_powered_on_in_provider" do
    it "requeues if the VM didn't start" do
      expect(@task).to receive(:powered_on_in_provider?).and_return(false)
      expect(@task).to receive(:requeue_phase)

      @task.poll_destination_powered_on_in_provider

      expect(@task.phase_context[:power_on_wait_count]).to eq(1)
    end

    it "moves on if the vm started" do
      expect(@task).to receive(:powered_on_in_provider?).and_return(true)
      expect(@task).to receive(:poll_destination_powered_off_in_provider)

      @task.poll_destination_powered_on_in_provider

      expect(@task.phase_context[:power_on_wait_count]).to be_nil
    end

    it "raises if the vm failed to start" do
      @task.phase_context[:power_on_wait_count] = 121

      expect { @task.poll_destination_powered_on_in_provider }.to raise_error(MiqException::MiqProvisionError)
    end
  end
end
