RSpec.describe MiqRemoteConsoleWorker::Runner do
  describe '#check_internal_thread' do
    subject do
      w = described_class.allocate
      allow(w).to receive(:worker_initialization)
      w.send(:initialize, :guid => MiqRemoteConsoleWorker.create_worker_record.guid)
      w
    end

    let(:worker) { double }
    let(:app) { RemoteConsole::RackServer.new }

    it 'exits if the thread is not running' do
      subject.instance_variable_set(:@worker, worker)
      allow(worker).to receive(:rails_application).and_return(app)
      expect(subject).to receive(:do_exit)

      app.instance_variable_get(:@transmitter).kill
      loop do
        break if !app.instance_variable_get(:@transmitter).alive?
        sleep 0.1
      end
      subject.check_internal_thread
    end
  end
end
