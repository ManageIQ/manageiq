describe VmCloud do
  let(:ems) { FactoryBot.create(:ems_cloud) }
  let(:user) { FactoryBot.create(:user, :userid => 'test') }
  let(:queue_name) { 'vm_cloud_queue' }

  subject { FactoryBot.create(:vm_cloud, :ext_management_system => ems) }

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

  context "queued methods" do
    before do
      allow(ems).to receive(:queue_name_for_ems_operations).and_return(queue_name)
    end

    it 'queues an associate floating IP task with associate_floating_ip_queue' do
      ip_address = '1.2.3.4'
      task_id = subject.associate_floating_ip_queue(user.userid, ip_address)

      expect(MiqTask.find(task_id)).to have_attributes(
        :name   => "associating floating IP with Instance for user #{user.userid}",
        :state  => "Queued",
        :status => "Ok"
      )

      expect(MiqQueue.where(:class_name => described_class.name).first).to have_attributes(
        :class_name  => described_class.name,
        :method_name => 'associate_floating_ip',
        :role        => 'ems_operations',
        :queue_name  => queue_name,
        :zone        => ems.my_zone,
        :args        => [ip_address]
      )
    end

    it 'requires an ip address for the associate floating ip queue task' do
      expect { subject.associate_floating_ip_queue }.to raise_error(ArgumentError)
    end
  end
end
