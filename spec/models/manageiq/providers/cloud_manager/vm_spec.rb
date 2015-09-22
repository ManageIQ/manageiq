require "spec_helper"

describe VmCloud do
  it "#post_create_actions" do
    expect(subject).to receive(:reconnect_events)
    expect(subject).to receive(:classify_with_parent_folder_path)
    expect(MiqEvent).to receive(:raise_evm_event).with(subject, "vm_create", :vm => subject)

    subject.post_create_actions
  end
end
