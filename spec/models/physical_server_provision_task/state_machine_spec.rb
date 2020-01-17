RSpec.describe PhysicalServerProvisionTask do
  let(:server) { FactoryBot.create(:physical_server) }

  subject { described_class.new(:source => server) }

  describe '#run_provision' do
    context 'when missing source' do
      let(:server) { nil }
      it do
        expect { subject.run_provision }.to raise_error(MiqException::MiqProvisionError)
      end
    end

    context 'when ok' do
      it do
        expect(subject).to receive(:signal).with(:start_provisioning)
        subject.run_provision
      end
    end
  end

  it '#done_provisioning' do
    expect(subject).to receive(:signal).with(:mark_as_completed)
    expect(subject).to receive(:update_and_notify_parent)
    subject.done_provisioning
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
      before { subject.update_attribute(:status, 'Error') }
      it do
        expect(log).to receive(:info).with(satisfy { |msg| msg.include?('Errored') })
        subject.finish
      end
    end

    context 'when task has completed' do
      before { subject.update_attribute(:status, 'Ok') }
      it do
        expect(log).to receive(:info).with(satisfy { |msg| msg.include?('... Complete') })
        subject.finish
      end
    end
  end
end
