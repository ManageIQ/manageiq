describe ManageIQ::Providers::AnsibleOperationWorkflow do
  let(:options) { [{"ENV" => "VAR"}, %w(arg1 arg2), "/path/to/playbook"] }

  context ".create_job" do
    it "leaves job waiting to start" do
      job = described_class.create_job(*options)
      expect(job.state).to eq("waiting_to_start")
    end
  end

  context ".signal" do
    let(:job) { described_class.create_job(*options).tap { |job| job.state = state } }

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
end
