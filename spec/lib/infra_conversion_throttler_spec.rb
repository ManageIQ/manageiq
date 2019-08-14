RSpec.describe InfraConversionThrottler, :v2v do
  let(:ems) { FactoryBot.create(:ext_management_system, :zone => FactoryBot.create(:zone), :api_version => '4.2.4') }
  let(:host) { FactoryBot.create(:host_redhat, :ext_management_system => ems) }
  let(:vm) { FactoryBot.create(:vm_openstack, :ext_management_system => ems) }
  let(:task_waiting) { FactoryBot.create(:service_template_transformation_plan_task, :source => vm) }
  let(:task_running_1) { FactoryBot.create(:service_template_transformation_plan_task, :source => vm) }
  let(:task_running_2) { FactoryBot.create(:service_template_transformation_plan_task, :source => vm) }
  let(:job_waiting) { FactoryBot.create(:infra_conversion_job, :state => 'waiting_to_start') }
  let(:job_running_1) { FactoryBot.create(:infra_conversion_job, :state => 'running') }
  let(:job_running_2) { FactoryBot.create(:infra_conversion_job, :state => 'running') }

  before do
    allow(host).to receive(:supports_conversion_host?).and_return(true)
    allow(vm).to receive(:supports_conversion_host?).and_return(true)
  end

  context '.start_conversions' do
    let(:conversion_host1) { FactoryBot.create(:conversion_host, :max_concurrent_tasks => 2, :vddk_transport_supported => true, :resource => host) }
    let(:conversion_host2) { FactoryBot.create(:conversion_host, :max_concurrent_tasks => 2, :vddk_transport_supported => true, :resource => vm) }

    before do
      allow(task_waiting).to receive(:destination_ems).and_return(ems)
      allow(task_waiting).to receive(:preflight_check).and_return(:status => 'Ok', :message => 'Preflight check is successful')
      allow(job_waiting).to receive(:migration_task).and_return(task_waiting)
      allow(described_class).to receive(:pending_conversion_jobs).and_return(ems => [job_waiting])
      allow(ems).to receive(:conversion_hosts).and_return([conversion_host1, conversion_host2])
      allow(conversion_host1).to receive(:check_ssh_connection).and_return(true)
      allow(conversion_host2).to receive(:check_ssh_connection).and_return(true)
      allow(conversion_host1).to receive(:authentication_check).and_return([true, 'passed'])
      allow(conversion_host2).to receive(:authentication_check).and_return([true, 'passed'])
    end

    it 'will abort conversion job if task fails preflight check' do
      allow(task_waiting).to receive(:preflight_check).and_return(:status => 'Error', :message => 'Fake error message')
      expect(job_waiting).to receive(:abort_conversion).with('Fake error message', 'error')
      described_class.start_conversions
    end

    it 'will not start a job when ems limit hit' do
      ems.miq_custom_set('MaxTransformationRunners', 2)
      allow(conversion_host1).to receive(:active_tasks).and_return([1])
      allow(conversion_host2).to receive(:active_tasks).and_return([1])
      expect(job_waiting).not_to receive(:queue_signal)
      described_class.start_conversions
    end

    it 'will not start a job when conversion_host limit hit' do
      ems.miq_custom_set('MaxTransformationRunners', 100)
      allow(conversion_host1).to receive(:active_tasks).and_return([1, 2])
      allow(conversion_host2).to receive(:active_tasks).and_return([1, 2])
      expect(job_waiting).not_to receive(:queue_signal)
      described_class.start_conversions
    end

    it 'will start a job when limits are not hit' do
      allow(conversion_host1).to receive(:active_tasks).and_return([1, 2])
      allow(conversion_host2).to receive(:active_tasks).and_return([1])
      expect(job_waiting).to receive(:queue_signal).with(:start)
      described_class.start_conversions
      expect(task_waiting.conversion_host.id).to eq(conversion_host2.id)
      expect(task_waiting.options[:conversion_host_name]).to eq(conversion_host2.name)
    end
  end

  context '.apply_limits' do
    let(:conversion_host) { FactoryBot.create(:conversion_host, :resource => vm, :cpu_limit => '50') }

    before do
      allow(described_class).to receive(:running_conversion_jobs).and_return(conversion_host => [job_running_1, job_running_2])
      allow(conversion_host).to receive(:active_tasks).and_return([1, 2])
      allow(job_running_1).to receive(:migration_task).and_return(task_running_1)
      allow(job_running_2).to receive(:migration_task).and_return(task_running_2)
    end

    it 'does not set limit when virt-v2v-wrapper has not started' do
      expect(conversion_host).not_to receive(:apply_task_limits)
      described_class.apply_limits
    end

    it 'calls apply_task_limits with limits hash when virt-v2v-wrapper has started' do
      path = '/tmp/fake_throttling_file'
      limits = {
        :cpu     => '25',
        :network => 'unlimited'
      }
      task_running_1.options[:virtv2v_wrapper] = { 'throttling_file' => path }
      task_running_2.options[:virtv2v_wrapper] = { 'throttling_file' => path }
      expect(conversion_host).to receive(:apply_task_limits).twice.with(path, limits)
      described_class.apply_limits
      expect(task_running_1.reload.options[:virtv2v_limits]).to eq(limits)
      expect(task_running_2.reload.options[:virtv2v_limits]).to eq(limits)
    end

    it 'does not call apply_task_limits when limits have not changed' do
      path = '/tmp/fake_throttling_file'
      limits = {
        :cpu     => '25',
        :network => 'unlimited'
      }
      task_running_1.update_options(:virtv2v_limits => limits)
      task_running_2.update_options(:virtv2v_limits => limits)
      expect(conversion_host).not_to receive(:apply_task_limits).with(path, limits)
      described_class.apply_limits
    end
  end
end
