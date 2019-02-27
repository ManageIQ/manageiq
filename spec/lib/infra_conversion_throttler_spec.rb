describe InfraConversionThrottler do
  let(:ems) { FactoryBot.create(:ext_management_system, :zone => FactoryBot.create(:zone)) }
  let(:host) { FactoryBot.create(:host, :ext_management_system => ems) }
  let(:vm) { FactoryBot.create(:vm_or_template, :ext_management_system => ems) }
  let(:task) { FactoryBot.create(:service_template_transformation_plan_task, :source => vm) }
  let(:job) { FactoryBot.create(:infra_conversion_job, :state => 'waiting_to_start') }

  before do
    allow(host).to receive(:supports_conversion_host?).and_return(true)
    allow(vm).to receive(:supports_conversion_host?).and_return(true)
  end

  context '.start_conversions' do
    let(:conversion_host1) { FactoryBot.create(:conversion_host, :max_concurrent_tasks => 2, :vddk_transport_supported => true, :resource => host) }
    let(:conversion_host2) { FactoryBot.create(:conversion_host, :max_concurrent_tasks => 2, :vddk_transport_supported => true, :resource => vm) }

    before do
      allow(task).to receive(:destination_ems).and_return(ems)
      allow(job).to receive(:migration_task).and_return(task)
      allow(described_class).to receive(:pending_conversion_jobs).and_return(ems => [job])
      allow(ems).to receive(:conversion_hosts).and_return([conversion_host1, conversion_host2])
      allow(conversion_host1).to receive(:check_ssh_connection).and_return(true)
      allow(conversion_host2).to receive(:check_ssh_connection).and_return(true)
    end

    it 'will not start a job when ems limit hit' do
      ems.miq_custom_set('Max Transformation Runners', 2)
      allow(conversion_host1).to receive(:active_tasks).and_return([1])
      allow(conversion_host2).to receive(:active_tasks).and_return([1])
      expect(job).not_to receive(:queue_signal)
      described_class.start_conversions
    end

    it 'will not start a job when conversion_host limit hit' do
      ems.miq_custom_set('Max Transformation Runners', 100)
      allow(conversion_host1).to receive(:active_tasks).and_return([1, 2])
      allow(conversion_host2).to receive(:active_tasks).and_return([1, 2])
      expect(job).not_to receive(:queue_signal)
      described_class.start_conversions
    end

    it 'will start a job when limits are not hit' do
      allow(conversion_host1).to receive(:active_tasks).and_return([1, 2])
      allow(conversion_host2).to receive(:active_tasks).and_return([1])
      expect(job).to receive(:queue_signal).with(:start)
      described_class.start_conversions
      expect(task.conversion_host.id).to eq(conversion_host2.id)
    end
  end
end
