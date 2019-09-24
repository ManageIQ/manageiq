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

shared_examples_for "End-to-end State Machine Run" do
  it "Completes Successfully" do
    expect(task).to be_kind_of(ManageIQ::Providers::Redhat::InfraManager::Provision)
    task.options[:vm_target_name] = options[:vm_target_name] # HACK: Automate usually does this

    @queue           = []
    @called_states   = []
    @signaled_states = []

    allow(task).to receive(:signal).and_wrap_original do |_method, *args|
      @called_state = args.first
      expect(expected_states_with_counts.keys).to include(@called_state)
      @signaled_states << @called_state
      @queue |= [@called_state]
    end

    task.run_provision # Get the state machine rolling

    loop { dequeue_method || break }

    ssec = @signaled_states.element_counts
    actual_states_with_counts = @called_states.element_counts.each_with_object({}) do |(state, count), hash|
      hash.store_path(state, :calls, count)
      hash.store_path(state, :signals, ssec[state])
    end
    expect(actual_states_with_counts).to eq(expected_states_with_counts)
  end
end
