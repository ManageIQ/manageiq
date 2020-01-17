RSpec.describe Service::LinkingWorkflow do
  let(:service)  { FactoryBot.create(:service) }
  let(:provider) { FactoryBot.create(:ems_vmware) }
  let(:uid_ems_array) { ["423c9963-378c-813f-1dbd-630e464d59d4", "423cf3e2-e319-3953-993f-fd8513db951d"] }
  let(:options) do
    {
      :target_class  => provider.class.name,
      :target_id     => provider.id,
      :uid_ems_array => uid_ems_array,
      :service_id    => service.id
    }
  end
  let(:job) { described_class.create_job(options) }

  context 'run_native_op' do
    subject { job.run_native_op }

    it 'raises an error if service is not found' do
      options[:service_id] = 999
      expect(job).to receive(:signal).with(:abort, "Job [#{job.id}] [#{job.name}] aborted: didn't find service ID: [999] to link to", "error")
      subject
    end

    it 'raises an error if provider is not found' do
      options[:target_id] = 999
      msg = "Job [#{job.id}] [#{job.name}] aborted: didn't find provider class: [#{provider.class.name}] ID: [999] to refresh"
      expect(job).to receive(:signal).with(:abort, msg, "error")
      subject
    end

    it 'calls refresh if not all VMs found in DB' do
      expect(job).to receive(:queue_signal).with(:refresh)
      subject
    end

    it 'calls post_refresh if all VMs found in DB' do
      uid_ems_array.each { |uid| FactoryBot.create(:vm_vmware, :uid_ems => uid, :ems_id => provider.id) }
      expect(job).to receive(:signal).with(:post_refresh)
      subject
    end
  end

  context 'post_refresh' do
    subject { job.post_refresh }

    it 'links found VMs to service' do
      uid_ems_array.each { |uid| FactoryBot.create(:vm_vmware, :uid_ems => uid, :ems_id => provider.id) }
      subject
      expect(service.vms.count).to eq(2)
    end
  end

  context 'state transitions' do
    %w(start refresh poll_refresh post_refresh finish abort_job cancel error).each do |signal|
      shared_examples_for "allows #{signal} signal" do
        it signal.to_s do
          expect(job).to receive(signal.to_sym)
          job.signal(signal.to_sym)
        end
      end
    end

    %w(start refresh poll_refresh post_refresh).each do |signal|
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

      it_behaves_like 'doesn\'t allow refresh signal'
      it_behaves_like 'doesn\'t allow poll_refresh signal'
      it_behaves_like 'doesn\'t allow post_refresh signal'
    end

    context 'running' do
      before do
        job.state = 'running'
      end

      it_behaves_like 'allows refresh signal'
      it_behaves_like 'allows post_refresh signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow poll_refresh signal'
    end

    context 'refreshing' do
      before do
        job.state = 'refreshing'
      end

      it_behaves_like 'allows poll_refresh signal'
      it_behaves_like 'allows post_refresh signal'
      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow refresh signal'
    end

    context 'post_refreshing' do
      before do
        job.state = 'post_refreshing'
      end

      it_behaves_like 'allows finish signal'
      it_behaves_like 'allows abort_job signal'
      it_behaves_like 'allows cancel signal'
      it_behaves_like 'allows error signal'

      it_behaves_like 'doesn\'t allow start signal'
      it_behaves_like 'doesn\'t allow refresh signal'
      it_behaves_like 'doesn\'t allow poll_refresh signal'
      it_behaves_like 'doesn\'t allow post_refresh signal'
    end
  end
end
