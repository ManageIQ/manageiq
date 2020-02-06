RSpec.describe PhysicalServerProvisionRequest do
  it '.TASK_DESCRIPTION' do
    expect(described_class::TASK_DESCRIPTION).to eq('Physical Server Provisioning')
  end

  it '.SOURCE_CLASS_NAME' do
    expect(described_class::SOURCE_CLASS_NAME).to eq('PhysicalServer')
  end

  it '.request_task_class' do
    expect(described_class.request_task_class).to eq(PhysicalServerProvisionTask)
  end

  it '#description' do
    expect(subject.description).to eq('Physical Server Provisioning')
  end

  it '#my_role' do
    expect(subject.my_role).to eq('ems_operations')
  end

  it "#my_queue_name" do
    expect(subject.my_queue_name).to be_nil
  end

  describe '.new_request_task' do
    before do
      allow(ems.class).to receive(:provision_class).and_return(task)
    end

    let(:server) { FactoryBot.create(:physical_server, :ext_management_system => ems) }
    let(:ems)    { FactoryBot.create(:ems_physical_infra) }
    let(:task)   { double('TASK') }

    context 'when source is ok' do
      it do
        expect(task).to receive(:new).with(:source_id => server.id)
        described_class.new_request_task(:source_id => server.id)
      end
    end

    context 'when source is missing' do
      it do
        expect { described_class.new_request_task(:source_id => 'missing') }.to raise_error(MiqException::MiqProvisionError)
      end
    end

    context 'when source is lacking EMS' do
      before { server.update!(:ext_management_system => nil) }
      it do
        expect { described_class.new_request_task(:source_id => server.id) }.to raise_error(MiqException::MiqProvisionError)
      end
    end
  end
end
