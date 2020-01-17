RSpec.describe ManageIQ::Providers::CloudManager::MetricsCapture do
  include Spec::Support::MetricHelper

  before do
    MiqRegion.seed
  end

  let(:miq_server) { EvmSpecHelper.local_miq_server }
  let(:ems)  { FactoryBot.create(:ems_openstack, :zone => miq_server.zone) }

  describe ".capture_ems_targets" do
    before do
      availability_zone = FactoryBot.create(:availability_zone_target)
      ems.availability_zones << availability_zone
      availability_zone.vms = FactoryBot.create_list(:vm_openstack, 2, :ems_id => ems.id)
      availability_zone.vms.push(FactoryBot.create(:vm_openstack, :ems_id => nil))
      # vms not in availability zone:
      FactoryBot.create_list(:vm_openstack, 3, :ems_id => ems.id)

      MiqQueue.delete_all
    end

    it "finds enabled targets" do
      targets = described_class.new(nil, ems).send(:capture_ems_targets)
      assert_cloud_targets_enabled targets
      expect(targets.map { |t| t.class.name }).to match_array(%w[ManageIQ::Providers::Openstack::CloudManager::Vm ManageIQ::Providers::Openstack::CloudManager::Vm ManageIQ::Providers::Openstack::CloudManager::Vm ManageIQ::Providers::Openstack::CloudManager::Vm ManageIQ::Providers::Openstack::CloudManager::Vm])
    end
  end

  private

  def assert_cloud_targets_enabled(targets)
    targets.each do |t|
      expected_enabled = case t
                         # Vm's perf_capture_enabled? is its availability_zone's perf_capture setting,
                         #   or true if it has no availability_zone
                         when Vm then                t.availability_zone ? t.availability_zone.perf_capture_enabled? : true
                         when AvailabilityZone then  t.perf_capture_enabled?
                         when Storage then           t.perf_capture_enabled?
                         end
      expect(expected_enabled).to be_truthy
    end
  end
end
