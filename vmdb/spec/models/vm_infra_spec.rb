require "spec_helper"

describe VmInfra do

  context "#post_create_actions" do
    it "without a host relationship" do
      expect(subject).to receive(:reconnect_events)
      expect(subject).to receive(:classify_with_parent_folder_path)
      expect(MiqEvent).to receive(:raise_evm_event).with(subject, "vm_create", :vm => subject, :host => nil)

      subject.post_create_actions
    end

    it "with a host relationship" do
      subject.host = FactoryGirl.build(:host)

      expect(subject).to receive(:reconnect_events)
      expect(subject).to receive(:classify_with_parent_folder_path)
      expect(MiqEvent).to receive(:raise_evm_event).with(subject, "vm_create", :vm => subject, :host => subject.host)
      expect(subject).to receive(:inherit_host_mgt_tags)
      expect(subject).to receive(:post_create_autoscan)

      subject.post_create_actions
    end
  end

  context "#inherit_host_mgt_tags" do
    it "without a host" do
      expect(subject).to_not receive(:add_tag)

      subject.send(:inherit_host_mgt_tags)
    end

    context "with a host" do
      let(:host) { subject.host = FactoryGirl.build(:host, :settings => {:inherit_mgt_tags => false}) }

      it "inherit_mgt_tags is false" do
        subject.host = host

        expect(subject).to_not receive(:add_tag)

        subject.send(:inherit_host_mgt_tags)
      end

      it "inherit_mgt_tags is true" do
        subject.host = host
        subject.host.inherit_mgt_tags = true

        expect(subject).to receive(:tag_add)

        subject.send(:inherit_host_mgt_tags)
      end
    end
  end

  context "#post_create_autoscan" do
    it "without a host" do
      expect(subject).to_not receive(:scan)

      subject.send(:post_create_autoscan)
    end

    context "with a host" do
      let(:host) { FactoryGirl.create(:host, :settings => {:autoscan => false}) }

      it "autoscan is false" do
        subject.host = host

        expect(subject).to_not receive(:scan)

        subject.send(:post_create_autoscan)
      end

      it "autoscan is true" do
        subject.host = host
        subject.host.autoscan = true

        expect(subject).to receive(:scan)

        subject.send(:post_create_autoscan)
      end
    end
  end
end
