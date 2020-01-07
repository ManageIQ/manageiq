class ManageIQ::Providers::CloudManager::MetricsCapture < ManageIQ::Providers::BaseManager::MetricsCapture
  # @return vms under all availability zones
  #         and vms under no availability zone
  # NOTE: some stacks (e.g. nova) default to no availability zone
  def capture_ems_targets(options = {})
    MiqPreloader.preload([ems], :vms => [{:availability_zone => :tags}, :ext_management_system])

    ems.vms.select do |vm|
      vm.state == 'on' && (vm.availability_zone.nil? || vm.availability_zone.perf_capture_enabled?)
    end
  end
end
