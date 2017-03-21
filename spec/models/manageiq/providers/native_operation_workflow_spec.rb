describe ManageIQ::Providers::NativeOperationWorkflow do
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

    context 'waiting_to_start' do
      before do
        @job.state = 'waiting_to_start'
      end

      it 'allows start signal' do
        expect(@job).to receive(:start)
        @job.signal(:start)
      end

      it 'doesn\'t allow poll_native_task signal' do
        expect { @job.signal(:poll_native_task) }.to raise_error(RuntimeError, /poll_native_task is not permitted at state waiting_to_start/)
      end

      it 'doesn\'t allow refresh signal' do
        expect { @job.signal(:refresh) }.to raise_error(RuntimeError, /refresh is not permitted at state waiting_to_start/)
      end

      it 'doesn\'t allow poll_refresh signal' do
        expect { @job.signal(:poll_refresh) }.to raise_error(RuntimeError, /poll_refresh is not permitted at state waiting_to_start/)
      end
    end

    context 'running' do
      before do
        @job.state = 'running'
      end

      it 'allows poll_native_task signal' do
        expect(@job).to receive(:poll_native_task)
        @job.signal(:poll_native_task)
      end

      it 'allows refresh signal' do
        expect(@job).to receive(:refresh)
        @job.signal(:refresh)
      end

      it 'doesn\'t allow start signal' do
        expect { @job.signal(:start) }.to raise_error(RuntimeError, /start is not permitted at state running/)
      end
    end

    context 'refreshing' do
      before do
        @job.state = 'refreshing'
      end

      it 'allows poll_refresh signal' do
        expect(@job).to receive(:poll_refresh)
        @job.signal(:poll_refresh)
      end

      it 'allows notify signal' do
        expect(@job).to receive(:notify)
        @job.signal(:notify)
      end

      it 'doesn\'t allow start signal' do
        expect { @job.signal(:start) }.to raise_error(RuntimeError, /start is not permitted at state refreshing/)
      end

      it 'doesn\'t allow poll_native_task signal' do
        expect { @job.signal(:poll_native_task) }.to raise_error(RuntimeError, /poll_native_task is not permitted at state refreshing/)
      end

      it 'doesn\'t allow refresh signal' do
        expect { @job.signal(:refresh) }.to raise_error(RuntimeError, /refresh is not permitted at state refreshing/)
      end
    end
  end

  context "refresh" do
    before do
      vm = FactoryGirl.create(:vm)

      options = {
        :target_id    => vm.id,
        :target_class => vm.class.name,
      }

      @job = described_class.create_job(options)
      @job.state = 'running'
    end

    it 'sets the refresh_task_ids in the context' do
      refresh_task = FactoryGirl.create(:miq_task)
      expect(EmsRefresh).to receive(:queue_refresh_task).and_return([refresh_task.id])
      expect(@job).to receive(:queue_signal).with(:poll_refresh)

      @job.signal(:refresh)

      expect(@job.context[:refresh_task_ids]).to eq([refresh_task.id])
    end

    it 'calls error if queuing the refresh failed' do
      expect(EmsRefresh).to receive(:queue_refresh_task).and_return(nil)
      expect(@job).to receive(:queue_signal).with(:error, "Failed to queue refresh", "error")

      @job.signal(:refresh)
    end
  end

  context "poll_refresh" do
    before do
      @job = described_class.create_job({})
      @job.state = 'refreshing'
    end

    it 'with a refresh task that is still running' do
      refresh_task = FactoryGirl.create(:miq_task)
      @job.context[:refresh_task_ids] = [refresh_task.id]

      expect(@job).to receive(:queue_signal).with(:poll_refresh, anything)

      @job.signal(:poll_refresh)
    end

    it 'with a refresh task that failed' do
      refresh_task = FactoryGirl.create(:miq_task, :status => MiqTask::STATUS_ERROR)
      @job.context[:refresh_task_ids] = [refresh_task.id]

      expect(@job).to receive(:queue_signal).with(:error, "Refresh failed", "error")

      @job.signal(:poll_refresh)
    end

    it 'with a refresh task that is still running' do
      refresh_task = FactoryGirl.create(:miq_task, :state => MiqTask::STATE_FINISHED)
      @job.context[:refresh_task_ids] = [refresh_task.id]

      expect(@job).to receive(:queue_signal).with(:notify)

      @job.signal(:poll_refresh)
    end
  end

  context "notify" do
    before do
      vm = FactoryGirl.create(:vm)

      options = {
        :target_id    => vm.id,
        :target_class => vm.class.name,
      }

      @job = described_class.create_job(options)
      @job.state = 'refreshing'
    end

    it 'with a successful job' do
      @job.status = "ok"

      expect(Notification).to receive(:create)
      @job.signal(:notify)
    end

    it 'with an unsuccessful job' do
      @job.status = "error"

      expect(Notification).to receive(:create)
      @job.signal(:notify)
    end
  end
end
