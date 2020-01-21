module Metric::CiMixin::Targets
  def perf_capture_always?
    case self
    # For now allowing capturing for all OpenstackInfra hosts and clusters
    when ManageIQ::Providers::Openstack::InfraManager::Host, ManageIQ::Providers::Openstack::InfraManager::Cluster then true
    when ManageIQ::Providers::Kubernetes::ContainerManager::Container then true
    when ManageIQ::Providers::Kubernetes::ContainerManager::ContainerGroup then true
    when ManageIQ::Providers::Kubernetes::ContainerManager::ContainerNode then true
    when Service then true
    # going to treat an availability_zone like a host wrt perf_capture settings
    when Host, EmsCluster, AvailabilityZone, HostAggregate then Metric::Targets.perf_capture_always[:host_and_cluster]
    when Storage then                            Metric::Targets.perf_capture_always[:storage]
    else;                                    false
    end
  end
  alias_method :perf_capture_always, :perf_capture_always?

  def perf_capture_enabled?
    @perf_capture_enabled ||= (perf_capture_always? || self.is_tagged_with?("capture_enabled", :ns => "/performance"))
  end
  alias_method :perf_capture_enabled, :perf_capture_enabled?
  Vmdb::Deprecation.deprecate_methods(self, :perf_capture_enabled => :perf_capture_enabled?)

  # TODO: Should enabling a Host also enable the cluster?
  def perf_capture_enabled=(enable)
    ns = "/performance"
    enable ? tag_add('capture_enabled', :ns => ns) : tag_with('', :ns => ns)

    # Clear tag association cache instead of full reload.
    @association_cache.except!(:tags, :taggings)

    @perf_capture_enabled = (perf_capture_always? || enable)
  end
end
