RSpec.describe PhysicalServerFirmwareUpdateTask do
  let(:server)  { FactoryBot.create(:physical_server) }
  let(:src_ids) { [server.id] }

  subject { described_class.new(:options => { :src_ids => src_ids }) }

  describe '#run_firmware_update' do
    context 'when ok' do
      it do
        expect(subject).to receive(:signal).with(:start_firmware_update)
        subject.run_firmware_update
      end
    end
  end

  it '#done_firmware_update' do
    expect(subject).to receive(:signal).with(:mark_as_completed)
    expect(subject).to receive(:update_and_notify_parent)
    subject.done_firmware_update
  end

  it '#mark_as_completed' do
    expect(subject).to receive(:signal).with(:finish)
    expect(subject).to receive(:update_and_notify_parent)
    subject.mark_as_completed
  end

  describe '#finish' do
    before { allow(subject).to receive(:_log).and_return(log) }

    let(:log) { double('LOG') }

    context 'when task has errored' do
      before { subject.update(:status => 'Error') }
      it do
        expect(log).to receive(:info).with(satisfy { |msg| msg.include?('Errored') })
        subject.finish
      end
    end

    context 'when task has completed' do
      before { subject.update(:status => 'Ok') }
      it do
        expect(log).to receive(:info).with(satisfy { |msg| msg.include?('... Complete') })
        subject.finish
      end
    end
  end
end
