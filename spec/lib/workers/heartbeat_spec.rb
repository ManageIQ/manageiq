require "workers/heartbeat"

shared_examples_for "heartbeat file checker" do |heartbeat_file = nil|
  # This is used instead of just passing in the `heartbeat_file` value directly
  # into the method because we can splat it in the argument list and force a "no
  # args" method call in each of the tests
  let(:file_check_args)    { [heartbeat_file].compact }
  let(:calculated_hb_file) { Pathname.new(heartbeat_file || ENV["WORKER_HEARTBEAT_FILE"]) }
  around do |example|
    FileUtils.mkdir_p(calculated_hb_file.parent)
    File.write(calculated_hb_file, "")

    example.run

    FileUtils.rm_f(calculated_hb_file.to_s)
  end

  it "returns false when the heartbeat file does not exist" do
    FileUtils.rm_f calculated_hb_file.to_s # Early delete
    expect(Workers::Heartbeat.file_check(*file_check_args)).to eq(false)
  end

  it "returns true with a newly created heartbeat file with no content" do
    expect(Workers::Heartbeat.file_check(*file_check_args)).to eq(true)
  end

  it "returns false with a stale heartbeat file with no content" do
    to_the_future = (2.minutes + 2.seconds).from_now
    Timecop.travel(to_the_future) do
      expect(Workers::Heartbeat.file_check(*file_check_args)).to eq(false)
    end
  end

  it "returns true with a heartbeat file with content within the timeout" do
    # Set timeout in heartbeat file
    File.write(calculated_hb_file, 3.minutes.from_now)

    to_the_future = (2.minutes + 2.seconds).from_now
    Timecop.travel(to_the_future) do
      expect(Workers::Heartbeat.file_check(*file_check_args)).to eq(true)
    end
  end
end

describe Workers::Heartbeat do
  describe ".file_check" do
    context "using the default heartbeat_file" do
      let(:test_heartbeat_file) { ManageIQ.root.join("tmp", "spec", "test.hb") }

      around do |example|
        # This is given the highest priority when calling
        # Workers::MiqDefaults.heartbeat_file.
        #
        # Trying to avoid using mocks...
        old_env = ENV["WORKER_HEARTBEAT_FILE"]
        ENV["WORKER_HEARTBEAT_FILE"] = test_heartbeat_file.to_s

        example.run

        ENV["WORKER_HEARTBEAT_FILE"] = old_env
      end

      it_should_behave_like "heartbeat file checker"
    end

    context "when passing in a filepath as an argument" do
      other_heartbeat_file = ManageIQ.root.join("tmp", "spec", "other.hb").to_s

      it_should_behave_like "heartbeat file checker", other_heartbeat_file
    end
  end

  describe "#post_message_for_workers" do
    let(:started_worker)  { FactoryBot.create(:miq_ui_worker, :status => MiqWorker::STATUS_STARTED,  :last_heartbeat => 30.seconds.ago.utc) }
    let(:stopping_worker) { FactoryBot.create(:miq_ui_worker, :status => MiqWorker::STATUS_STOPPING, :last_heartbeat => 30.seconds.ago.utc) }
    let(:server)          { EvmSpecHelper.local_miq_server(:miq_workers => [started_worker, stopping_worker]) }

    before do
      allow(server).to receive(:workers_last_heartbeat) { Time.now.utc }
      require 'miq-process'
      allow(MiqProcess).to receive(:alive?).with(started_worker.pid).and_return(true)
      allow(Process).to receive(:kill)
    end

    it "validates current/starting workers for memory usage, avoiding stale miq_workers" do
      server.sync_child_worker_settings
      started_worker.update!(:unique_set_size => 4.gigabytes)

      expect(server.post_message_for_workers(started_worker.class.name)).to eq([started_worker.id])
      expect(MiqWorker.exists?(started_worker.id)).to be_falsy
      expect(server.post_message_for_workers(started_worker.class.name)).to eq([])
    end
  end
end
