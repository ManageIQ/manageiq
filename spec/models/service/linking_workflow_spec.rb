RSpec.describe Service::LinkingWorkflow do
  let(:service)  { FactoryBot.create(:service) }
  let(:provider) { FactoryBot.create(:ems_infra) }
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

  before do
    allow(ExtManagementSystem).to receive(:find_by).and_call_original
    allow(ExtManagementSystem).to receive(:find_by).with(:id => provider.id).and_return(provider)
  end

  context 'run_native_op' do
    subject { job.run_native_op }

    it 'raises an error if service is not found' do
      options[:service_id] = -1
      expect(job).to receive(:signal).with(:abort, "Job [#{job.id}] [#{job.name}] aborted: didn't find service ID: [-1] to link to", "error")
      subject
    end

    it 'raises an error if provider is not found' do
      options[:target_id] = -1
      msg = "Job [#{job.id}] [#{job.name}] aborted: didn't find provider class: [#{provider.class.name}] ID: [-1] to refresh"
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

    it 'finishes even if not all vms are found' do
      FactoryBot.create(:vm_vmware, :uid_ems => uid_ems_array.first, :ems_id => provider.id)
      subject
      expect(service.vms.count).to eq(1)
    end
  end

  context '#refresh_target' do
    subject { job.refresh_target }

    context 'when provider supports targeted refresh' do
      before do
        allow(provider).to receive(:allow_targeted_refresh?).and_return(true)
      end

      it 'creates InventoryRefresh::Target for each VM UID' do
        expect(subject).to all(be_a(InventoryRefresh::Target))

        subject.each_with_index do |target, index|
          expect(target.manager).to eq(provider)
          expect(target.association).to eq(:vms)
          expect(target.manager_ref).to eq(:ems_ref => uid_ems_array[index])
        end
      end

      it 'handles single VM UID' do
        options[:uid_ems_array] = ["single-vm-uid"]
        expect(subject.size).to eq(1)
        expect(subject.first.manager_ref).to eq(:ems_ref => "single-vm-uid")
      end
    end

    context 'when provider does not support targeted refresh' do
      before do
        allow(provider).to receive(:allow_targeted_refresh?).and_return(false)
      end

      it 'returns the EMS provider for full refresh' do
        expect(subject).to eq(provider)
      end
    end

    context 'when provider record doesn\'t exist' do
      before do
        options[:target_id] = -1
      end

      it 'returns nil' do
        expect(subject).to be_nil
      end
    end
  end

  context 'state transitions' do
    %w[start refresh poll_refresh post_refresh finish abort_job cancel error].each do |signal|
      shared_examples_for "allows #{signal} signal" do
        it signal.to_s do
          expect(job).to receive(signal.to_sym)
          job.signal(signal.to_sym)
        end
      end
    end

    %w[start refresh poll_refresh post_refresh].each do |signal|
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
