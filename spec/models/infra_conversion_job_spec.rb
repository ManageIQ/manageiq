RSpec.describe InfraConversionJob, :v2v do
  let(:vm)      { FactoryBot.create(:vm_or_template) }
  let(:request) { FactoryBot.create(:service_template_transformation_plan_request) }
  let(:task)    { FactoryBot.create(:service_template_transformation_plan_task, :miq_request => request, :source => vm) }
  let(:options) { {:target_class => task.class.name, :target_id => task.id} }
  let(:job)     { described_class.create_job(options) }

  context '.create_job' do
    it 'leaves job waiting to start' do
      job = described_class.create_job(options)
      expect(job.state).to eq('waiting_to_start')
    end
  end

  context 'state transitions' do
    %w[start poll_automate_state_machine finish abort_job cancel error].each do |signal|
      shared_examples_for "allows #{signal} signal" do
        it signal.to_s do
          expect(job).to receive(signal.to_sym)
          job.signal(signal.to_sym)
        end
      end
    end

    %w[start poll_automate_state_machine].each do |signal|
      shared_examples_for "doesn't allow #{signal} signal" do
        it signal.to_s do
          expect { job.signal(signal.to_sym) }.to raise_error(RuntimeError, /#{signal} is not permitted at state #{job.state}/)
        end
      end
    end

    context 'waiting_to_start' do
      before do
        job.state = 'waiting_to_start'
      end

      it_behaves_like 'allows start signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow poll_automate_state_machine signal'
    end

    context 'started' do
      before do
        job.state = 'started'
      end

      it_behaves_like 'allows poll_automate_state_machine signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
    end

    context 'running_in_automate' do
      before do
        job.state = 'running_in_automate'
      end

      it_behaves_like 'allows poll_automate_state_machine signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
    end
  end

  context 'operations' do
    let(:poll_interval) { Settings.transformation.job.retry_interval }

    context '#start' do
      it 'to poll_automate_state_machine when preflight_check passes' do
        expect(job).to receive(:queue_signal).with(:poll_automate_state_machine)
        job.signal(:start)
        expect(task.reload.state).to eq('migrate')
        expect(task.options[:workflow_runner]).to eq('automate')
      end
    end

    context '#poll_automate_state_machine' do
      before do
        job.state = 'running_in_automate'
      end

      it 'to poll_automate_state_machine when migration_task.state is not finished' do
        task.update!(:state => 'migrate')
        Timecop.freeze(2019, 2, 6) do
          expect(job).to receive(:queue_signal).with(:poll_automate_state_machine, :deliver_on => Time.now.utc + poll_interval)
          job.signal(:poll_automate_state_machine)
        end
      end

      it 'to finish when migration_task.state is finished' do
        task.update!(:state => 'finished', :status => 'Ok')
        Timecop.freeze(2019, 2, 6) do
          expect(job).to receive(:queue_signal).with(:finish)
          job.signal(:poll_automate_state_machine)
          expect(job.status).to eq(task.status)
        end
      end

      it 'abort_conversion when poll_automate_state_machine times out' do
        job.context[:retries_running_in_automate] = 8640
        expect(job).to receive(:abort_conversion).with('Polling timed out', 'error')
        job.signal(:poll_automate_state_machine)
      end
    end
  end
end
