describe ManageIQ::Providers::InfraManager::MetricsCapture do
  include Spec::Support::MetricHelper

  before do
    MiqRegion.seed
    @zone = EvmSpecHelper.local_miq_server.zone
  end

  describe ".capture_ems_targets" do
    context "with vmware", :with_enabled_disabled_vmware do
      it "finds enabled targets" do
        targets = described_class.new(nil, @ems_vmware).send(:capture_ems_targets)
        assert_infra_targets_enabled targets
        expect(targets.map { |t| t.class.name }).to match_array(%w[ManageIQ::Providers::Vmware::InfraManager::Vm ManageIQ::Providers::Vmware::InfraManager::Host ManageIQ::Providers::Vmware::InfraManager::Host ManageIQ::Providers::Vmware::InfraManager::Vm ManageIQ::Providers::Vmware::InfraManager::Host Storage])
      end

      it "finds enabled targets excluding storages" do
        targets = described_class.new(nil, @ems_vmware).send(:capture_ems_targets, :exclude_storages => true)
        assert_infra_targets_enabled targets
        expect(targets.map { |t| t.class.name }).to match_array(%w[ManageIQ::Providers::Vmware::InfraManager::Vm ManageIQ::Providers::Vmware::InfraManager::Host ManageIQ::Providers::Vmware::InfraManager::Host ManageIQ::Providers::Vmware::InfraManager::Vm ManageIQ::Providers::Vmware::InfraManager::Host])
      end
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
