describe ManageIQ::Providers::CloudManager::MetricsCapture do
  include Spec::Support::MetricHelper

  before do
    MiqRegion.seed
    @zone = EvmSpecHelper.local_miq_server.zone
  end

  describe ".capture_ems_targets" do
    before do
      @ems_openstack = FactoryBot.create(:ems_openstack, :zone => @zone)
      @availability_zone = FactoryBot.create(:availability_zone_target)
      @ems_openstack.availability_zones << @availability_zone
      @vms_in_az = FactoryBot.create_list(:vm_openstack, 2, :ems_id => @ems_openstack.id)
      @availability_zone.vms = @vms_in_az
      @availability_zone.vms.push(FactoryBot.create(:vm_openstack, :ems_id => nil))
      @vms_not_in_az = FactoryBot.create_list(:vm_openstack, 3, :ems_id => @ems_openstack.id)

      MiqQueue.delete_all
    end

    it "finds enabled targets" do
      targets = described_class.new(nil, @ems_openstack).send(:capture_ems_targets)
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
