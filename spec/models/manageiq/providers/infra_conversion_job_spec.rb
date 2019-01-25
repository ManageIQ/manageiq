describe ManageIQ::Providers::InfraConversionJob do
  let(:vm)      { FactoryBot.create(:vm_or_template) }
  let(:request) { FactoryBot.create(:service_template_transformation_plan_request) }
  let(:task)    { FactoryBot.create(:service_template_transformation_plan_task, :miq_request => request, :request_type => 'transformation_plan', :source => vm) }
  let(:options) { {:target_class => task.class.name, :target_id => task.id} }

  context '.create_job' do
    it 'leaves job waiting to start' do
      job = described_class.create_job(options)

      expect(job.state).to eq('waiting_to_start')
    end
  end

  context 'state transitions' do
    before do
      @job = described_class.create_job(options)
    end

    %w(start poll_conversion finish abort_job cancel error).each do |signal|
      shared_examples_for "allows #{signal} signal" do
        it signal.to_s do
          expect(@job).to receive(signal.to_sym)
          @job.signal(signal.to_sym)
        end
      end
    end

    %w(start poll_conversion post_conversion).each do |signal|
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

      it_behaves_like 'doesn\'t allow poll_conversion signal'
    end

    context 'running' do
      before do
        @job.state = 'running'
      end

      it_behaves_like 'allows poll_conversion signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
    end
  end
end
