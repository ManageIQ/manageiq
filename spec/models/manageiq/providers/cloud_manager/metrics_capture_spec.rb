describe ManageIQ::Providers::CloudManager::MetricsCapture do
  include Spec::Support::MetricHelper

  before do
    MiqRegion.seed
    @zone = EvmSpecHelper.local_miq_server.zone
  end

  describe ".capture_ems_targets" do
    context "with openstack", :with_openstack_and_availability_zones do
      it "finds enabled targets" do
        targets = described_class.new(nil, @ems_openstack).send(:capture_ems_targets)
        assert_cloud_targets_enabled targets, %w[ManageIQ::Providers::Openstack::CloudManager::Vm ManageIQ::Providers::Openstack::CloudManager::Vm ManageIQ::Providers::Openstack::CloudManager::Vm ManageIQ::Providers::Openstack::CloudManager::Vm ManageIQ::Providers::Openstack::CloudManager::Vm]
      end
    end
  end

  private

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
