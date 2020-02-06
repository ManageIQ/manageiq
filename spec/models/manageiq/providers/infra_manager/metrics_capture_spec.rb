RSpec.describe ManageIQ::Providers::InfraManager::MetricsCapture do
  include Spec::Support::MetricHelper

  let(:miq_server) { EvmSpecHelper.local_miq_server }
  let(:ems) { FactoryBot.create(:ems_vmware, :zone => miq_server.zone) }

  before do
    MiqRegion.seed
    storages = FactoryBot.create_list(:storage_vmware, 2)
    storages.each_with_index { |st, i| st.perf_capture_enabled = i.even? }
    clusters = FactoryBot.create_list(:ems_cluster, 2, :ext_management_system => ems)
    clusters.each_with_index { |cl, i| cl.perf_capture_enabled = i.even? }

    6.times do |n|
      host = FactoryBot.create(:host_vmware, :ext_management_system => ems, :ems_cluster => clusters[n / 2], :perf_capture_enabled => n.even?)
      2.times do |i|
        FactoryBot.create(:vm_vmware, :ext_management_system => ems, :host => host, :raw_power_state => i.even? ? "poweredOn" : "poweredOff")
      end
      host.storages << storages[n / 3]
    end

    MiqQueue.delete_all
    ems.reload
  end

  describe ".capture_ems_targets" do
    it "finds enabled targets" do
      targets = described_class.new(nil, ems).capture_ems_targets
      assert_infra_targets_enabled targets
      expect(targets.map { |t| t.class.name }).to match_array(%w[ManageIQ::Providers::Vmware::InfraManager::Vm ManageIQ::Providers::Vmware::InfraManager::Host ManageIQ::Providers::Vmware::InfraManager::Host ManageIQ::Providers::Vmware::InfraManager::Vm ManageIQ::Providers::Vmware::InfraManager::Host Storage])
    end

    it "finds enabled targets excluding storages" do
      targets = described_class.new(nil, ems).capture_ems_targets(:exclude_storages => true)
      assert_infra_targets_enabled targets
      expect(targets.map { |t| t.class.name }).to match_array(%w[ManageIQ::Providers::Vmware::InfraManager::Vm ManageIQ::Providers::Vmware::InfraManager::Host ManageIQ::Providers::Vmware::InfraManager::Host ManageIQ::Providers::Vmware::InfraManager::Vm ManageIQ::Providers::Vmware::InfraManager::Host])
    end
  end

  private

  def assert_infra_targets_enabled(targets)
    targets.each do |t|
      expected_enabled = case t
                         when Vm then      t.host.perf_capture_enabled?
                         when Host then    t.ems_cluster ? t.ems_cluster.perf_capture_enabled? : t.perf_capture_enabled?
                         when Storage then t.perf_capture_enabled?
                         end
      expect(expected_enabled).to be_truthy
    end
  end
end
