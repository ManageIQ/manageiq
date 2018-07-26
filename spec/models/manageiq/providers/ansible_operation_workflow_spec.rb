describe ManageIQ::Providers::AnsibleOperationWorkflow do
  let(:job)     { described_class.create_job(*options).tap { |job| job.state = state } }
  let(:options) { [{"ENV" => "VAR"}, %w(arg1 arg2), "/path/to/playbook"] }
  let(:state)   { "waiting_to_start" }

  context ".create_job" do
    it "leaves job waiting to start" do
      expect(job.state).to eq("waiting_to_start")
    end
  end

  context ".signal" do
    %w(start pre_playbook run_playbook poll_runner post_playbook finish abort_job cancel error).each do |signal|
      shared_examples_for "allows #{signal} signal" do
        it signal.to_s do
          expect(job).to receive(signal.to_sym)
          job.signal(signal.to_sym)
        end
      end
    end

    %w(start pre_playbook run_playbook poll_runner post_playbook).each do |signal|
      shared_examples_for "doesn't allow #{signal} signal" do
        it signal.to_s do
          expect { job.signal(signal.to_sym) }.to raise_error(RuntimeError, /#{signal} is not permitted at state #{job.state}/)
        end
      end
    end

    context "waiting_to_start" do
      let(:state) { "waiting_to_start" }

      it_behaves_like "allows start signal"
      it_behaves_like "allows finish signal"
      it_behaves_like "allows abort_job signal"
      it_behaves_like "allows cancel signal"
      it_behaves_like "allows error signal"

      it_behaves_like "doesn't allow run_playbook signal"
      it_behaves_like "doesn't allow poll_runner signal"
      it_behaves_like "doesn't allow post_playbook signal"
    end

    context "pre_playbook" do
      let(:state) { "pre_playbook" }

      it_behaves_like "allows run_playbook signal"
      it_behaves_like "allows finish signal"
      it_behaves_like "allows abort_job signal"
      it_behaves_like "allows cancel signal"
      it_behaves_like "allows error signal"

      it_behaves_like "doesn't allow start signal"
      it_behaves_like "doesn't allow poll_runner signal"
      it_behaves_like "doesn't allow post_playbook signal"
    end

    context "running" do
      let(:state) { "running" }

      it_behaves_like "allows poll_runner signal"
      it_behaves_like "allows finish signal"
      it_behaves_like "allows abort_job signal"
      it_behaves_like "allows cancel signal"
      it_behaves_like "allows error signal"

      it_behaves_like "doesn't allow start signal"
      it_behaves_like "doesn't allow pre_playbook signal"
    end

    context "post_playbook" do
      let(:state) { "post_playbook" }

      it_behaves_like "allows finish signal"
      it_behaves_like "allows abort_job signal"
      it_behaves_like "allows cancel signal"
      it_behaves_like "allows error signal"

      it_behaves_like "doesn't allow start signal"
      it_behaves_like "doesn't allow pre_playbook signal"
      it_behaves_like "doesn't allow run_playbook signal"
      it_behaves_like "doesn't allow poll_runner signal"
      it_behaves_like "doesn't allow post_playbook signal"
    end
  end

  context ".run_playbook" do
    let(:state) { "pre_playbook" }

    it "ansible-runner succeeds" do
      uuid = "b4146f49-aec1-4f8f-a9aa-94afc99d5d80"
      expect(Ansible::Runner).to receive(:run_async).and_return(uuid)
      expect(job).to receive(:queue_signal).with(:poll_runner)

      job.signal(:run_playbook)

      expect(job.context[:ansible_runner_uuid]).to eq(uuid)
    end

    it "ansible-runner fails" do
      expect(Ansible::Runner).to receive(:run_async).and_return(nil)
      expect(job).to receive(:queue_signal).with(:error)

      job.signal(:run_playbook)
    end
  end

  context ".poll_runner" do
    let(:state) { "running" }
    let(:uuid)  { "b4146f49-aec1-4f8f-a9aa-94afc99d5d80" }

    before do
      job.context[:ansible_runner_uuid] = uuid
      job.save!
    end

    it "ansible-runner completed" do
      expect(Ansible::Runner).to receive(:running?).with(uuid).and_return(false)
      expect(job).to receive(:queue_signal).with(:post_playbook)

      job.signal(:poll_runner)
    end

    it "ansible-runner still running" do
      now = Time.now
      allow(Time).to receive(:now).and_return(now)
      expect(Ansible::Runner).to receive(:running?).with(uuid).and_return(true)
      expect(job).to receive(:queue_signal).with(:poll_runner, :deliver_on => now + 1.minute)

      job.signal(:poll_runner)
    end
  end
end
