RSpec.describe VmCloud do
  let(:ems) { FactoryBot.create(:ems_cloud) }
  let(:user) { FactoryBot.create(:user, :userid => 'test') }

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
        :queue_name  => ems.queue_name_for_ems_operations,
        :zone        => ems.my_zone,
        :args        => [ip_address]
      )
    end

    it 'requires an both a userid and ip address for the associate floating ip queue task' do
      expect { subject.associate_floating_ip_queue }.to raise_error(ArgumentError)
      expect { subject.associate_floating_ip_queue(user.userid) }.to raise_error(ArgumentError)
    end

    it 'queues an dissociate floating IP task with disassociate_floating_ip_queue' do
      ip_address = '1.2.3.4'
      task_id = subject.disassociate_floating_ip_queue(user.userid, ip_address)

      expect(MiqTask.find(task_id)).to have_attributes(
        :name   => "disassociating floating IP with Instance for user #{user.userid}",
        :state  => "Queued",
        :status => "Ok"
      )

      expect(MiqQueue.where(:class_name => described_class.name).first).to have_attributes(
        :class_name  => described_class.name,
        :method_name => 'disassociate_floating_ip',
        :role        => 'ems_operations',
        :queue_name  => ems.queue_name_for_ems_operations,
        :zone        => ems.my_zone,
        :args        => [ip_address]
      )
    end

    it 'requires an both a userid and ip address for the dissociate floating ip queue task' do
      expect { subject.disassociate_floating_ip_queue }.to raise_error(ArgumentError)
      expect { subject.disassociate_floating_ip_queue(user.userid) }.to raise_error(ArgumentError)
    end

    it 'queues an add security group task with add_security_group_queue' do
      security_group = FactoryBot.create(:security_group)
      task_id = subject.add_security_group_queue(user.userid, security_group.id)

      expect(MiqTask.find(task_id)).to have_attributes(
        :name   => "adding Security Group to Instance for user #{user.userid}",
        :state  => "Queued",
        :status => "Ok"
      )

      expect(MiqQueue.where(:class_name => described_class.name).first).to have_attributes(
        :class_name  => described_class.name,
        :method_name => 'add_security_group',
        :role        => 'ems_operations',
        :queue_name  => ems.queue_name_for_ems_operations,
        :zone        => ems.my_zone,
        :args        => [security_group.id]
      )
    end

    it 'requires an both a userid and security group for the add security group queue task' do
      expect { subject.add_security_group_queue }.to raise_error(ArgumentError)
      expect { subject.add_security_group_queue(user.userid) }.to raise_error(ArgumentError)
    end

    it 'queues a remove security group task with remove_security_group_queue' do
      security_group = FactoryBot.create(:security_group)
      task_id = subject.remove_security_group_queue(user.userid, security_group.id)

      expect(MiqTask.find(task_id)).to have_attributes(
        :name   => "removing Security Group from Instance for user #{user.userid}",
        :state  => "Queued",
        :status => "Ok"
      )

      expect(MiqQueue.where(:class_name => described_class.name).first).to have_attributes(
        :class_name  => described_class.name,
        :method_name => 'remove_security_group',
        :role        => 'ems_operations',
        :queue_name  => ems.queue_name_for_ems_operations,
        :zone        => ems.my_zone,
        :args        => [security_group.id]
      )
    end

    it 'requires an both a userid and security group for the remove security group queue task' do
      expect { subject.remove_security_group_queue }.to raise_error(ArgumentError)
      expect { subject.remove_security_group_queue(user.userid) }.to raise_error(ArgumentError)
    end

    it 'queues a live migration task with live_migrate_queue' do
      task_id = described_class.live_migrate_queue(user.userid, subject)

      expect(MiqTask.find(task_id)).to have_attributes(
        :name   => "migrating Instance for user #{user.userid}",
        :state  => "Queued",
        :status => "Ok"
      )

      expect(MiqQueue.where(:class_name => described_class.name).first).to have_attributes(
        :class_name  => described_class.name,
        :method_name => 'live_migrate',
        :role        => 'ems_operations',
        :queue_name  => subject.queue_name_for_ems_operations,
        :zone        => subject.my_zone,
        :args        => [subject.id, {}]
      )
    end

    it 'requires an both a userid and vm for the live migration queue task' do
      expect { described_class.live_migrate_queue }.to raise_error(ArgumentError)
      expect { described_class.live_migrate_queue(user.userid) }.to raise_error(ArgumentError)
    end

    it 'queues an evacuation task with evacuate_queue' do
      task_id = described_class.evacuate_queue(user.userid, subject)

      expect(MiqTask.find(task_id)).to have_attributes(
        :name   => "evacuating Instance for user #{user.userid}",
        :state  => "Queued",
        :status => "Ok"
      )

      expect(MiqQueue.where(:class_name => described_class.name).first).to have_attributes(
        :class_name  => described_class.name,
        :method_name => 'evacuate',
        :role        => 'ems_operations',
        :queue_name  => subject.queue_name_for_ems_operations,
        :zone        => subject.my_zone,
        :args        => [subject.id, {}]
      )
    end

    it 'requires an both a userid and vm for the evacuation queue task' do
      expect { described_class.evacuate_queue }.to raise_error(ArgumentError)
      expect { described_class.evacuate_queue(user.userid) }.to raise_error(ArgumentError)
    end
  end
end
