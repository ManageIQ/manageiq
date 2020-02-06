RSpec.describe VmInfra do
  context "#post_create_actions" do
    it "without a host relationship" do
      expect(subject).to receive(:reconnect_events)
      expect(subject).to receive(:classify_with_parent_folder_path)
      expect(MiqEvent).to receive(:raise_evm_event).with(subject, "vm_create", :vm => subject, :host => nil)

      subject.post_create_actions
    end

    it "with a host relationship" do
      subject.host = FactoryBot.build(:host)

      expect(subject).to receive(:reconnect_events)
      expect(subject).to receive(:classify_with_parent_folder_path)
      expect(MiqEvent).to receive(:raise_evm_event).with(subject, "vm_create", :vm => subject, :host => subject.host)

      subject.post_create_actions
    end
  end
end
