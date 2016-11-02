describe VmCloud do
  subject { FactoryGirl.create(:vm_cloud) }

  it "#post_create_actions" do
    expect(subject).to receive(:reconnect_events)
    expect(subject).to receive(:classify_with_parent_folder_path)
    expect(MiqEvent).to receive(:raise_evm_event).with(subject, "vm_create", :vm => subject)

    subject.post_create_actions
  end

  describe "#service and #direct_service" do
    let(:service_root) { FactoryGirl.create(:service) }
    let(:service)      { FactoryGirl.create(:service, :parent => service_root) }

    context "provisioned through a vm provisioning service" do
      before { service.add_resource!(subject) }

      it "finds the service that provisioned the vm" do
        expect(subject.service).to eq(service_root)
        expect(subject.direct_service).to eq(service)
      end
    end

    context "provisioned through an orchestration provisioning service" do
      before do
        stack = FactoryGirl.create(:orchestration_stack, :direct_vms => [subject])
        service.add_resource!(stack)
      end

      it "finds the service that provisioned the stack" do
        expect(subject.service).to eq(service_root)
        expect(subject.direct_service).to eq(service)
      end
    end
  end
end
