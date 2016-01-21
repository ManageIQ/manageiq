shared_examples_for "common rhev state machine methods" do
  it "#customize_destination" do
    allow(@task).to receive(:get_provider_destination).and_return(nil)
    allow(@task).to receive(:update_and_notify_parent)

    expect(@task).to receive(:configure_container)
    expect(@task).to receive(:configure_destination)

    @task.customize_destination
  end
end
