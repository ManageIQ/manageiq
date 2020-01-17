RSpec.describe MiqServer::WorkerManagement::Heartbeat do
  context "#persist_last_heartbeat" do
    let(:miq_server) { EvmSpecHelper.local_miq_server }
    let(:worker)     { FactoryBot.create(:miq_worker, :miq_server_id => miq_server.id) }

    # Iterating by 5 each time to allow enough spacing to be more than 1 second
    # apart when using be_within(x).of(t)
    let!(:first_heartbeat) { Time.now.utc }
    let!(:heartbeat_file)  { "/path/to/worker.hb" }

    around do |example|
      ENV["WORKER_HEARTBEAT_METHOD"] = "file"
      ENV["WORKER_HEARTBEAT_FILE"]   = heartbeat_file
      example.run
      ENV.delete("WORKER_HEARTBEAT_METHOD")
      ENV.delete("WORKER_HEARTBEAT_FILE")
    end

    context "with an existing heartbeat file" do
      it "sets initial and subsequent heartbeats" do
        expect(File).to receive(:exist?).with(heartbeat_file).and_return(true, true)
        expect(File).to receive(:mtime).with(heartbeat_file).and_return(first_heartbeat, first_heartbeat + 5)

        [0, 5].each do |i|
          Timecop.freeze(first_heartbeat) do
            miq_server.persist_last_heartbeat(worker)
          end

          expect(worker.reload.last_heartbeat).to be_within(1.second).of(first_heartbeat + i)
        end
      end
    end

    context "with a missing heartbeat file" do
      it "sets initial heartbeat only" do
        expect(File).to receive(:exist?).with(heartbeat_file).and_return(false).exactly(4).times
        expect(File).to receive(:mtime).with(heartbeat_file).never

        # This has different results first iteration of the loop compared to
        # the rest:
        #   1. Sets the initial heartbeat
        #   2. Doesn't update the worker's last_heartbeat value after that
        #
        # So the result from the database should not change after the first
        # iteration of the loop
        [0, 5, 10, 15].each do |i|
          Timecop.freeze(first_heartbeat + i) do
            miq_server.persist_last_heartbeat(worker)
          end

          expect(worker.reload.last_heartbeat).to be_within(1.second).of(first_heartbeat)
        end
      end
    end

    context "with a missing heartbeat file on the first validate" do
      it "sets initial heartbeat default, and updates the heartbeat from the file second" do
        expect(File).to receive(:exist?).with(heartbeat_file).and_return(false, true)
        expect(File).to receive(:mtime).with(heartbeat_file).and_return(first_heartbeat + 5)

        [0, 5].each do |i|
          Timecop.freeze(first_heartbeat) do
            miq_server.persist_last_heartbeat(worker)
          end

          expect(worker.reload.last_heartbeat).to be_within(1.second).of(first_heartbeat + i)
        end
      end
    end
  end
end
