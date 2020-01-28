RSpec.describe PhysicalServerFirmwareUpdateRequest do
  it '.TASK_DESCRIPTION' do
    expect(described_class::TASK_DESCRIPTION).to eq('Physical Server Firmware Update')
  end

  it '.SOURCE_CLASS_NAME' do
    expect(described_class::SOURCE_CLASS_NAME).to eq('PhysicalServer')
  end

  it '.request_task_class' do
    expect(described_class.request_task_class).to eq(PhysicalServerFirmwareUpdateTask)
  end

  it '#description' do
    expect(subject.description).to eq('Physical Server Firmware Update')
  end

  it '#my_role' do
    expect(subject.my_role).to eq('ems_operations')
  end

  describe '#my_queue_name' do
    let(:ems)             { FactoryBot.create(:ems_physical_infra) }
    let(:physical_server) { FactoryBot.create(:physical_server, :ext_management_system => ems) }

    it "returns the ems's queue_name_for_ems_operations" do
      expect(physical_server.queue_name_for_ems_operations).to eq(ems.queue_name_for_ems_operations)
    end
  end

  it '#requested_task_idx' do
    expect(subject.requested_task_idx).to eq([-1])
  end

  describe '.new_request_task' do
    before { allow(ems.class).to receive(:firmware_update_class).and_return(task) }

    let(:ems)    { FactoryBot.create(:ems_physical_infra) }
    let(:task)   { double('TASK') }

    it 'returns subclassed task' do
      expect(described_class).to receive(:affected_ems).and_return(ems)
      expect(task).to receive(:new).with('ATTRS')
      described_class.new_request_task('ATTRS')
    end
  end

  describe '.affected_physical_servers' do
    let(:attrs)   { { 'options' => {:src_ids => src_ids} } }
    let(:server1) { FactoryBot.create(:physical_server, :ems_id => 1) }
    let(:server2) { FactoryBot.create(:physical_server, :ems_id => 2) }
    let(:server3) { FactoryBot.create(:physical_server, :ems_id => 2) }

    context 'when no src_ids are given' do
      let(:src_ids) { [] }
      it 'handled error is raised' do
        expect { described_class.affected_physical_servers(attrs) }.to raise_error(MiqException::MiqFirmwareUpdateError)
      end
    end

    context 'when invalid src_ids are given' do
      let(:src_ids) { ['invalid'] }
      it 'handled error is raised' do
        expect { described_class.affected_physical_servers(attrs) }.to raise_error(MiqException::MiqFirmwareUpdateError)
      end
    end

    context 'when servers belong to different ems' do
      let(:src_ids) { [server1.id, server2.id] }
      it 'handled error is raised' do
        expect { described_class.affected_physical_servers(attrs) }.to raise_error(MiqException::MiqFirmwareUpdateError)
      end
    end

    context 'when all okay' do
      let(:src_ids) { [server2.id, server3.id] }
      it 'server list is returned' do
        expect(described_class.affected_physical_servers(attrs)).to eq([server2, server3])
      end
    end
  end

  it '#affected_physical_servers' do
    expect(described_class).to receive(:affected_physical_servers).and_return('RES')
    expect(subject.affected_physical_servers).to eq('RES')
  end

  describe '.affected_ems' do
    let(:ems)    { FactoryBot.create(:ems_physical_infra) }
    let(:server) { FactoryBot.create(:physical_server, :ems_id => ems.id) }

    it 'when all okay' do
      expect(described_class).to receive(:affected_physical_servers).and_return([server])
      expect(described_class.affected_ems(nil)).to eq(ems)
    end
  end

  it '#affected_ems' do
    expect(described_class).to receive(:affected_ems).and_return('RES')
    expect(subject.affected_ems).to eq('RES')
  end
end
