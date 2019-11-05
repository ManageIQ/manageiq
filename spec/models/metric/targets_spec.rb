describe Metric::Targets do
  before do
    MiqRegion.seed
    @zone = EvmSpecHelper.local_miq_server.zone
  end

  describe ".capture_ems_targets" do
    context "with vmware", :with_enabled_disabled_vmware do
      it "finds enabled targets" do
        targets = Metric::Targets.capture_ems_targets(@ems_vmware)
        assert_infra_targets_enabled targets, %w[ManageIQ::Providers::Vmware::InfraManager::Vm ManageIQ::Providers::Vmware::InfraManager::Host ManageIQ::Providers::Vmware::InfraManager::Host ManageIQ::Providers::Vmware::InfraManager::Vm ManageIQ::Providers::Vmware::InfraManager::Host Storage]
      end

      it "finds enabled targets excluding storages" do
        targets = Metric::Targets.capture_ems_targets(@ems_vmware, :exclude_storages => true)
        assert_infra_targets_enabled targets, %w[ManageIQ::Providers::Vmware::InfraManager::Vm ManageIQ::Providers::Vmware::InfraManager::Host ManageIQ::Providers::Vmware::InfraManager::Host ManageIQ::Providers::Vmware::InfraManager::Vm ManageIQ::Providers::Vmware::InfraManager::Host]
      end
    end

    context "with openstack", :with_openstack_and_availability_zones do
      it "finds enabled targets" do
        targets = Metric::Targets.capture_ems_targets(@ems_openstack)
        assert_cloud_targets_enabled targets, %w[ManageIQ::Providers::Openstack::CloudManager::Vm ManageIQ::Providers::Openstack::CloudManager::Vm ManageIQ::Providers::Openstack::CloudManager::Vm ManageIQ::Providers::Openstack::CloudManager::Vm ManageIQ::Providers::Openstack::CloudManager::Vm]
      end
    end
  end

  private

  def assert_infra_targets_enabled(targets, expected_types)
    # infra only
    selected_types = []
    targets.each do |t|
      selected_types << t.class.name

      expected_enabled = case t
                         when Vm then      t.host.perf_capture_enabled?
                         when Host then    t.perf_capture_enabled? || t.ems_cluster.perf_capture_enabled?
                         when Storage then t.perf_capture_enabled?
                         end
      expect(expected_enabled).to be_truthy
    end

    expect(selected_types).to match_array(expected_types)
  end

  def assert_cloud_targets_enabled(targets, expected_types)
    selected_types = []
    targets.each do |t|
      selected_types << t.class.name

      expected_enabled = case t
                         # Vm's perf_capture_enabled? is its availability_zone's perf_capture setting,
                         #   or true if it has no availability_zone
                         when Vm then                t.availability_zone ? t.availability_zone.perf_capture_enabled? : true
                         when AvailabilityZone then  t.perf_capture_enabled?
                         when Storage then           t.perf_capture_enabled?
                         end
      expect(expected_enabled).to be_truthy
    end

    expect(selected_types).to match_array(expected_types)
  end
end
