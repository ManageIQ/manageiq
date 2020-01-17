RSpec.describe ManageIQ::Providers::EmsRefreshWorkflow do
  context '.create_job' do
    it 'leaves job waiting to start' do
      options = {}
      job = described_class.create_job(options)

      expect(job.state).to eq('waiting_to_start')
    end
  end

  context 'state transitions' do
    before do
      @job = described_class.create_job({})
    end

    %w(start poll_native_task refresh poll_refresh post_refresh finish abort_job cancel error).each do |signal|
      shared_examples_for "allows #{signal} signal" do
        it signal.to_s do
          expect(@job).to receive(signal.to_sym)
          @job.signal(signal.to_sym)
        end
      end
    end

    %w(start poll_native_task refresh poll_refresh post_refresh).each do |signal|
      shared_examples_for "doesn't allow #{signal} signal" do
        it signal.to_s do
          expect { @job.signal(signal.to_sym) }.to raise_error(RuntimeError, /#{signal} is not permitted at state #{@job.state}/)
        end
      end
    end

    context 'waiting_to_start' do
      before do
        @job.state = 'waiting_to_start'
      end

      it_behaves_like 'allows start signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow poll_native_task signal'
      it_behaves_like 'doesn\'t allow refresh signal'
      it_behaves_like 'doesn\'t allow poll_refresh signal'
      it_behaves_like 'doesn\'t allow post_refresh signal'
    end

    context 'running' do
      before do
        @job.state = 'running'
      end

      it_behaves_like 'allows poll_native_task signal'
      it_behaves_like 'allows refresh signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow poll_refresh signal'
      it_behaves_like 'doesn\'t allow post_refresh signal'
    end

    context 'refreshing' do
      before do
        @job.state = 'refreshing'
      end

      it_behaves_like 'allows poll_refresh signal'
      it_behaves_like 'allows post_refresh signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow poll_native_task signal'
      it_behaves_like 'doesn\'t allow refresh signal'
    end

    context 'post_refreshing' do
      before do
        @job.state = 'post_refreshing'
      end

      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow poll_native_task signal'
      it_behaves_like 'doesn\'t allow refresh signal'
      it_behaves_like 'doesn\'t allow poll_refresh signal'
      it_behaves_like 'doesn\'t allow post_refresh signal'
    end
  end

  context "refresh" do
    before do
      vm = FactoryBot.create(:vm)

      options = {
        :target_id    => vm.id,
        :target_class => vm.class.name,
      }

      @job = described_class.create_job(options)
      @job.state = 'running'
    end

    it 'sets the refresh_task_ids in the context' do
      refresh_task = FactoryBot.create(:miq_task)
      expect(EmsRefresh).to receive(:queue_refresh_task).and_return([refresh_task.id])
      expect(@job).to receive(:queue_signal).with(:poll_refresh)

      @job.signal(:refresh)

      expect(@job.context[:refresh_task_ids]).to eq([refresh_task.id])
    end

    it 'calls error if queuing the refresh failed' do
      expect(EmsRefresh).to receive(:queue_refresh_task).and_return(nil)
      expect(@job).to receive(:queue_signal).with(:error)

      @job.signal(:refresh)

      expect(@job.status).to  eq("error")
      expect(@job.message).to eq("Failed to queue refresh")
    end
  end

  context "poll_refresh" do
    before do
      @job = described_class.create_job({})
      @job.state = 'refreshing'
    end

    it 'with a refresh task that is still running' do
      refresh_task = FactoryBot.create(:miq_task)
      @job.context[:refresh_task_ids] = [refresh_task.id]

      expect(@job).to receive(:queue_signal).with(:poll_refresh, anything)

      @job.signal(:poll_refresh)
    end

    it 'with a refresh task that failed' do
      refresh_task = FactoryBot.create(:miq_task, :status => MiqTask::STATUS_ERROR)
      @job.context[:refresh_task_ids] = [refresh_task.id]

      expect(@job).to receive(:queue_signal).with(:post_refresh)

      @job.signal(:poll_refresh)

      expect(@job.status).to  eq("error")
      expect(@job.message).to eq("Refresh failed")
    end

    it 'with a refresh task that finished' do
      refresh_task = FactoryBot.create(:miq_task, :state => MiqTask::STATE_FINISHED)
      @job.context[:refresh_task_ids] = [refresh_task.id]

      expect(@job).to receive(:queue_signal).with(:post_refresh)

      @job.signal(:poll_refresh)
    end
  end
end
