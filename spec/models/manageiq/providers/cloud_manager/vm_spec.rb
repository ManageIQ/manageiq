describe VmCloud do
  subject { FactoryBot.create(:vm_cloud) }

  context "relationships" do
    let(:resource_group) { FactoryBot.create(:resource_group) }
    before { subject.resource_group = resource_group }

    it "has one resource group" do
      expect(subject).to respond_to(:resource_group)
      expect(subject.resource_group).to eql(resource_group)
    end
  end

  it "#post_create_actions" do
    expect(subject).to receive(:reconnect_events)
    expect(subject).to receive(:classify_with_parent_folder_path)
    expect(MiqEvent).to receive(:raise_evm_event).with(subject, "vm_create", :vm => subject)

    subject.post_create_actions
  end

  describe "#service and #direct_service" do
    let(:service_root) { FactoryBot.create(:service) }
    let(:service)      { FactoryBot.create(:service, :parent => service_root) }

    context "provisioned through a vm provisioning service" do
      before { service.add_resource!(subject) }

      it "finds the service that provisioned the vm" do
        expect(subject.service).to eq(service_root)
        expect(subject.direct_service).to eq(service)
      end
    end

    context "provisioned through an orchestration provisioning service" do
      before do
        stack = FactoryBot.create(:orchestration_stack, :direct_vms => [subject])
        service.add_resource!(stack)
      end

      it "finds the service that provisioned the stack" do
        expect(subject.service).to eq(service_root)
        expect(subject.direct_service).to eq(service)
      end
    end
  end
end
