module Metric::CiMixin::Targets
  def perf_capture_always?
    case self
    # For now allowing capturing for all OpesntackInfra hosts
    when HostOpenstackInfra                ; true
    # going to treat an availability_zone like a host wrt perf_capture settings
    when Host, EmsCluster, AvailabilityZone; Metric::Targets.perf_capture_always[:host_and_cluster]
    when Storage;                            Metric::Targets.perf_capture_always[:storage]
    else;                                    false
    end
  end
  alias perf_capture_always perf_capture_always?

  def perf_capture_enabled?
    @perf_capture_enabled ||= (perf_capture_always? || self.is_tagged_with?("capture_enabled", :ns => "/performance"))
  end
  alias perf_capture_enabled perf_capture_enabled?

  #TODO: Should enabling a Host also enable the cluster?
  def perf_capture_enabled=(enable)
    ns = "/performance"
    enable ? self.tag_add('capture_enabled', :ns => ns) : self.tag_with('', :ns => ns)

    # Clear tag association cache instead of full reload.
    association_cache.except!(:tags, :taggings)

    @perf_capture_enabled = (perf_capture_always? || enable)
  end
end
