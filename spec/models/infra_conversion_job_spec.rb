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

  context 'state hash methods' do
    before do
      job.state = 'running_in_automate'
      job.context[:retries_running_in_automate] = 1728
    end

    context '.on_entry' do
      it 'initializes the state hash if it did not exist' do
        Timecop.freeze(2019, 2, 6) do
          expect(job.on_entry(nil, nil)).to eq(
            :state      => 'active',
            :status     => 'Ok',
            :started_on => Time.now.utc,
            :percent    => 0.0
          )
        end
      end
    end

    context '.on_retry' do
      it 'uses ad-hoc percentage if no progress is provided' do
        Timecop.freeze(2019, 2, 6) do
          state_hash = {
            :state      => 'active',
            :status     => 'Ok',
            :started_on => Time.now.utc - 1.minute,
            :percent    => 10.0
          }
          state_hash_diff = {
            :percent    => 20.0,
            :updated_on => Time.now.utc
          }
          expect(job.on_retry(state_hash, nil)).to eq(state_hash.merge(state_hash_diff))
        end
      end

      it 'uses percentage from progress hash' do
        Timecop.freeze(2019, 2, 6) do
          state_hash = {
            :state      => 'active',
            :status     => 'Ok',
            :started_on => Time.now.utc - 1.minute,
            :percent    => 10.0
          }
          state_hash_diff = {
            :percent    => 25.0,
            :updated_on => Time.now.utc
          }
          expect(job.on_retry(state_hash, :percent => 25.0)).to eq(state_hash.merge(state_hash_diff))
        end
      end
    end

    context '.on_exit' do
      it 'uses percentage from progress hash' do
        Timecop.freeze(2019, 2, 6) do
          state_hash = {
            :state      => 'active',
            :status     => 'Ok',
            :started_on => Time.now.utc - 1.minute,
            :percent    => 80.0
          }
          state_hash_diff = {
            :state      => 'finished',
            :percent    => 100.0,
            :updated_on => Time.now.utc
          }
          expect(job.on_exit(state_hash, nil)).to eq(state_hash.merge(state_hash_diff))
        end
      end
    end

    context '.on_error' do
      it 'uses percentage from progress hash' do
        Timecop.freeze(2019, 2, 6) do
          state_hash = {
            :state      => 'active',
            :status     => 'Ok',
            :started_on => Time.now.utc - 1.minute,
            :percent    => 80.0
          }
          state_hash_diff = {
            :state      => 'finished',
            :status     => 'Error',
            :updated_on => Time.now.utc
          }
          expect(job.on_error(state_hash, nil)).to eq(state_hash.merge(state_hash_diff))
        end
      end
    end

    context '.update_migration_task_progress' do
      it 'initializes the progress hash on entry if it does not exist' do
        Timecop.freeze(2019, 2, 6) do
          job.update_migration_task_progress(:on_entry, nil)
          expect(task.reload.options[:progress]).to eq(
            :current_state => 'running_in_automate',
            :percent       => 0.0,
            :states        => {
              :running_in_automate => {
                :state      => 'active',
                :status     => 'Ok',
                :started_on => Time.now.utc,
                :percent    => 0.0
              }
            }
          )
        end
      end

      it 'updates the task progress hash on retry without a state progress hash' do
        job.context[:retries_running_in_automate] = 1728
        Timecop.freeze(2019, 2, 6) do
          progress = {
            :current_state => 'running_in_automate',
            :percent       => 10.0,
            :states        => {
              :running_in_automate => {
                :state      => 'active',
                :status     => 'Ok',
                :started_on => Time.now.utc - 1.minute,
                :percent    => 10.0,
                :updated_on => Time.now.utc - 30.seconds
              }
            }
          }
          task.update_options(:progress => progress)
          job.update_migration_task_progress(:on_retry, nil)
          expect(task.reload.options[:progress]).to eq(
            :current_state => 'running_in_automate',
            :percent       => 10.0,
            :states        => {
              :running_in_automate => {
                :state      => 'active',
                :status     => 'Ok',
                :started_on => Time.now.utc - 1.minute,
                :percent    => 20.0,
                :updated_on => Time.now.utc
              }
            }
          )
        end
      end

      it 'updates the task progress hash on retry with a state progress hash' do
        job.context[:retries_running_in_automate] = 1728
        Timecop.freeze(2019, 2, 6) do
          progress = {
            :current_state => 'running_in_automate',
            :percent       => 10.0,
            :states        => {
              :running_in_automate => {
                :state      => 'active',
                :status     => 'Ok',
                :started_on => Time.now.utc - 1.minute,
                :percent    => 10.0,
                :updated_on => Time.now.utc - 30.seconds
              }
            }
          }
          task.update_options(:progress => progress)
          job.update_migration_task_progress(:on_retry, :percent => 30)
          expect(task.reload.options[:progress]).to eq(
            :current_state => 'running_in_automate',
            :percent       => 10.0,
            :states        => {
              :running_in_automate => {
                :state      => 'active',
                :status     => 'Ok',
                :started_on => Time.now.utc - 1.minute,
                :percent    => 30.0,
                :updated_on => Time.now.utc
              }
            }
          )
        end
      end

      it 'updates the task progress hash on exit' do
        job.context[:retries_running_in_automate] = 1728
        Timecop.freeze(2019, 2, 6) do
          progress = {
            :current_state => 'running_in_automate',
            :percent       => 10.0,
            :states        => {
              :running_in_automate => {
                :state      => 'active',
                :status     => 'Ok',
                :started_on => Time.now.utc - 1.minute,
                :percent    => 10.0,
                :updated_on => Time.now.utc - 30.seconds
              }
            }
          }
          task.update_options(:progress => progress)
          job.update_migration_task_progress(:on_exit, nil)
          expect(task.reload.options[:progress]).to eq(
            :current_state => 'running_in_automate',
            :percent       => 10.0,
            :states        => {
              :running_in_automate => {
                :state      => 'finished',
                :status     => 'Ok',
                :started_on => Time.now.utc - 1.minute,
                :percent    => 100.0,
                :updated_on => Time.now.utc
              }
            }
          )
        end
      end

      it 'updates the task progress hash on error' do
        job.context[:retries_running_in_automate] = 1728
        Timecop.freeze(2019, 2, 6) do
          progress = {
            :current_state => 'running_in_automate',
            :percent       => 10.0,
            :states        => {
              :running_in_automate => {
                :state      => 'active',
                :status     => 'Ok',
                :started_on => Time.now.utc - 1.minute,
                :percent    => 10.0,
                :updated_on => Time.now.utc - 30.seconds
              }
            }
          }
          task.update_options(:progress => progress)
          job.update_migration_task_progress(:on_error, nil)
          expect(task.reload.options[:progress]).to eq(
            :current_state => 'running_in_automate',
            :percent       => 10.0,
            :states        => {
              :running_in_automate => {
                :state      => 'finished',
                :status     => 'Error',
                :started_on => Time.now.utc - 1.minute,
                :percent    => 10.0,
                :updated_on => Time.now.utc
              }
            }
          )
        end
      end
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

  context 'transition methods' do
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
