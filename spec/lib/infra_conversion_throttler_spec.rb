RSpec.describe InfraConversionThrottler, :v2v do
  let(:src_ems) { FactoryBot.create(:ems_vmware) }
  let(:src_cluster) { FactoryBot.create(:ems_cluster, :ext_management_system => src_ems) }
  let(:src_vm) { FactoryBot.create(:vm_vmware, :ext_management_system => src_ems, :ems_cluster => src_cluster) }
  let(:dst_ems) { FactoryBot.create(:ems_openstack, :zone => FactoryBot.create(:zone)) }
  let(:dst_cluster) { FactoryBot.create(:ems_cluster_openstack, :ext_management_system => dst_ems) }
  let(:host) { FactoryBot.create(:host_redhat, :ext_management_system => dst_ems) }
  let(:vm) { FactoryBot.create(:vm_openstack, :ext_management_system => dst_ems) }

  let(:mapping) do
    FactoryBot.create(:transformation_mapping).tap do |tm|
      FactoryBot.create(:transformation_mapping_item,
                        :source                 => src_cluster,
                        :destination            => dst_cluster,
                        :transformation_mapping => tm)
    end
  end

  let(:catalog_item_options) do
    {
      :name        => 'Transformation Plan',
      :description => 'a description',
      :config_info => {
        :transformation_mapping_id => mapping.id,
        :actions                   => [
          {:vm_id => src_vm.id.to_s, :warm_migration => true}
        ],
      }
    }
  end

  let(:plan) { ServiceTemplateTransformationPlan.create_catalog_item(catalog_item_options) }
  let(:request) { FactoryBot.create(:service_template_transformation_plan_request, :source => plan) }

  let(:task_waiting) { FactoryBot.create(:service_template_transformation_plan_task, :miq_request => request, :request_type => 'transformation_plan', :source => src_vm, :state => 'queued') }
  let(:task_running_1) { FactoryBot.create(:service_template_transformation_plan_task, :miq_request => request, :request_type => 'transformation_plan', :source => src_vm, :state => 'migrate') }
  let(:task_running_2) { FactoryBot.create(:service_template_transformation_plan_task, :miq_request => request, :request_type => 'transformation_plan', :source => src_vm, :state => 'migrate') }
  let(:job_waiting) { FactoryBot.create(:infra_conversion_job, :target_class => 'ServiceTemplateTransformationPlanTask', :target_id => task_waiting.id, :state => 'waiting_to_start') }
  let(:job_running_1) { FactoryBot.create(:infra_conversion_job, :target_class => 'ServiceTemplateTransformationPlanTask', :target_id => task_running_1.id, :state => 'waiting_for_inventory_refresh') }
  let(:job_running_2) { FactoryBot.create(:infra_conversion_job, :target_class => 'ServiceTemplateTransformationPlanTask', :target_id => task_running_2.id, :state => 'aborting_virtv2v') }

  before do
    allow(host).to receive(:supports_conversion_host?).and_return(true)
    allow(vm).to receive(:supports_conversion_host?).and_return(true)
  end

  context '.start_conversions' do
    let(:conversion_host1) { FactoryBot.create(:conversion_host, :max_concurrent_tasks => 2, :vddk_transport_supported => true, :resource => host) }
    let(:conversion_host2) { FactoryBot.create(:conversion_host, :max_concurrent_tasks => 2, :vddk_transport_supported => true, :resource => vm) }

    before do
      allow(task_waiting).to receive(:preflight_check).and_return(:status => 'Ok', :message => 'Preflight check is successful')
      allow(job_waiting).to receive(:migration_task).and_return(task_waiting)
      allow(described_class).to receive(:pending_conversion_jobs).and_return(dst_ems => [job_waiting])
      allow(dst_ems).to receive(:conversion_hosts).and_return([conversion_host1, conversion_host2])
      allow(conversion_host1).to receive(:check_ssh_connection).and_return(true)
      allow(conversion_host2).to receive(:check_ssh_connection).and_return(true)
      allow(conversion_host1).to receive(:authentication_check).and_return([true, 'passed'])
      allow(conversion_host2).to receive(:authentication_check).and_return([true, 'passed'])
    end

    it 'will abort conversion job if task fails preflight check' do
      allow(task_waiting).to receive(:preflight_check).and_return(:status => 'Error', :message => 'Fake error message')
      expect(job_waiting).to receive(:abort_conversion).with("Fake error message", 'error')
      expect(described_class._log).to receive(:error).with("Preflight check for #{task_waiting.source.name} has failed: Fake error message. Discarding.")
      described_class.start_conversions
    end

    it 'will not start a job when ems limit hit' do
      dst_ems.miq_custom_set('MaxTransformationRunners', 2)
      allow(conversion_host1).to receive(:active_tasks).and_return([1])
      allow(conversion_host2).to receive(:active_tasks).and_return([1])
      expect(job_waiting).not_to receive(:queue_signal)
      described_class.start_conversions
    end

    it 'will not start a job when conversion_host limit hit' do
      dst_ems.miq_custom_set('MaxTransformationRunners', 100)
      allow(conversion_host1).to receive(:active_tasks).and_return([1, 2])
      allow(conversion_host2).to receive(:active_tasks).and_return([1, 2])
      expect(job_waiting).not_to receive(:queue_signal)
      described_class.start_conversions
    end

    it 'will not start a job if warm migration criteria are not met' do
      allow(conversion_host1).to receive(:active_tasks).and_return([1, 2])
      allow(conversion_host2).to receive(:active_tasks).and_return([1])
      conversion_host2.vddk_transport_supported = false
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
      allow(described_class).to receive(:running_conversion_jobs).and_return(conversion_host => [job_running_1], nil => [job_running_2])
    end

    it 'does not set limit when virt-v2v-wrapper has not started' do
      expect(conversion_host).not_to receive(:apply_task_limits)
      described_class.apply_limits
    end

    it 'calls apply_task_limits with limits hash when virt-v2v-wrapper has started' do
      task_running_1.conversion_host = conversion_host
      limits = {
        :cpu     => '50',
        :network => 'unlimited'
      }
      task_running_1.update_options(
        :virtv2v_started_on => Time.now.utc,
        :virtv2v_wrapper    => {
          'state_file'      => "/tmp/state_1.json",
          'throttling_file' => '/tmp/throttling_1.json'
        }
      )
      task_running_2.update_options(
        :virtv2v_started_on => Time.now.utc,
        :virtv2v_wrapper    => {
          'state_file'      => "/tmp/state_2.json"
        }
      )
      expect(conversion_host).to receive(:apply_task_limits).with('/tmp/throttling_1.json', limits)
      described_class.apply_limits
      expect(task_running_1.reload.options[:virtv2v_limits]).to eq(limits)
      expect(task_running_2.reload.options[:virtv2v_limits]).to be_nil
    end

    it 'does not call apply_task_limits when limits have not changed' do
      limits = {
        :cpu     => '50',
        :network => 'unlimited'
      }
      task_running_1.update_options(:virtv2v_limits => limits)
      task_running_2.update_options(:virtv2v_limits => limits)
      expect(conversion_host).not_to receive(:apply_task_limits).with(task_running_1.id, limits)
      expect(conversion_host).not_to receive(:apply_task_limits).with(task_running_2.id, limits)
      described_class.apply_limits
    end
  end
end
