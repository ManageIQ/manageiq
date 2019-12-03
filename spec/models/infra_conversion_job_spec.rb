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
    %w(start poll_conversion start_post_stage poll_post_stage finish abort_job cancel error).each do |signal|
      shared_examples_for "allows #{signal} signal" do
        it signal.to_s do
          expect(job).to receive(signal.to_sym)
          job.signal(signal.to_sym)
        end
      end
    end

    %w(start poll_conversion start_post_stage poll_post_stage).each do |signal|
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

      it_behaves_like 'doesn\'t allow poll_conversion signal'
      it_behaves_like 'doesn\'t allow start_post_stage signal'
      it_behaves_like 'doesn\'t allow poll_post_stage signal'
    end

    context 'running' do
      before do
        job.state = 'running'
      end

      it_behaves_like 'allows poll_conversion signal'
      it_behaves_like 'allows start_post_stage signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow poll_post_stage signal'
    end

    context 'post_conversion' do
      before do
        job.state = 'post_conversion'
      end

      it_behaves_like 'allows poll_post_stage signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow poll_conversion signal'
      it_behaves_like 'doesn\'t allow start_post_stage signal'
    end
  end

  context 'operations' do
    let(:poll_interval) { Settings.transformation.limits.conversion_polling_interval }

    before do
      allow(job).to receive(:migration_task).and_return(task)
    end

    context '#start' do
      it 'to poll_conversion when preflight_check passes' do
        expect(job).to receive(:queue_signal).with(:poll_conversion)
        job.signal(:start)
        expect(task.state).to eq('migrate')
        expect(task.options[:workflow_runner]).to eq('automate')
      end
    end

    context '#poll_conversion' do
      before do
        job.state = 'running'
        task.options[:virtv2v_wrapper] = {'state_file' => 'something'}
      end

      it 'to poll_conversion when migration_task.options[:virtv2v_wrapper] is nil' do
        task.options[:virtv2v_wrapper] = nil
        Timecop.freeze(2019, 2, 6) do
          expect(job).to receive(:queue_signal).with(:poll_conversion, :deliver_on => Time.now.utc + poll_interval)
          job.signal(:poll_conversion)
        end
      end

      it 'to poll_conversion when migration_task.options[:virtv2v_wrapper][:state_file] is nil' do
        task.options[:virtv2v_wrapper] = {'state_file' => nil}
        Timecop.freeze(2019, 2, 6) do
          expect(job).to receive(:queue_signal).with(:poll_conversion, :deliver_on => Time.now.utc + poll_interval)
          job.signal(:poll_conversion)
        end
      end

      it 'abort_conversion when get_conversion_state fails' do
        expect(task).to receive(:get_conversion_state).and_raise
        expect(job).to receive(:abort_conversion)
        job.signal(:poll_conversion)
      end

      it 'to poll_conversion when migration_task.options[:virtv2v_status] is active' do
        task.options[:virtv2v_status] = 'active'
        Timecop.freeze(2019, 2, 6) do
          expect(task).to receive(:get_conversion_state)
          expect(job).to receive(:queue_signal).with(:poll_conversion, :deliver_on => Time.now.utc + poll_interval)
          job.signal(:poll_conversion)
        end
      end

      it 'abort_conversion when migration_task.options[:virtv2v_status] is failed' do
        task.options[:virtv2v_status] = 'failed'
        expect(task).to receive(:get_conversion_state)
        expect(job).to receive(:abort_conversion)
        job.signal(:poll_conversion)
      end

      it 'to start_post_stage when migration_task.options[:virtv2v_status] is succeeded' do
        task.options[:virtv2v_status] = 'succeeded'
        expect(task).to receive(:get_conversion_state)
        expect(job).to receive(:queue_signal).with(:start_post_stage)
        job.signal(:poll_conversion)
      end

      it 'abort_conversion when migration_task.options[:virtv2v_status] is unknown' do
        task.options[:virtv2v_status] = '_'
        expect(task).to receive(:get_conversion_state)
        expect(job).to receive(:abort_conversion)
        job.signal(:poll_conversion)
      end

      it 'abort_conversion when poll_conversion times out' do
        job.options[:poll_conversion_max] = 24 * 60
        job.context[:poll_conversion_count] = 24 * 60
        expect(job).to receive(:abort_conversion)
        job.signal(:poll_conversion)
      end
    end

    context '#start_post_stage' do
      it 'to poll_post_stage when signaled :start_post_stage' do
        job.state = 'running'
        Timecop.freeze(2019, 2, 6) do
          expect(job).to receive(:queue_signal).with(:poll_post_stage, :deliver_on => Time.now.utc + poll_interval)
          job.signal(:start_post_stage)
        end
      end
    end

    context '#poll_post_stage' do
      before do
        job.state = 'post_conversion'
      end

      it 'to poll_post_stage when migration_task.state is not finished' do
        task.state = 'not-finished'
        Timecop.freeze(2019, 2, 6) do
          expect(job).to receive(:queue_signal).with(:poll_post_stage, :deliver_on => Time.now.utc + poll_interval)
          job.signal(:poll_post_stage)
        end
      end

      it 'to finish when migration_task.state is finished' do
        task.state = 'finished'
        task.status = 'whatever'
        Timecop.freeze(2019, 2, 6) do
          expect(job).to receive(:queue_signal).with(:finish)
          job.signal(:poll_post_stage)
          expect(job.status).to eq(task.status)
        end
      end

      it 'abort_conversion when poll_post_stage times out' do
        job.options[:poll_post_stage_max] = 30
        job.context[:poll_post_stage_count] = 30
        expect(job).to receive(:abort_conversion)
        job.signal(:poll_post_stage)
      end
    end
  end
end
