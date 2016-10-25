class ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::HawkularClient
  include ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::HawkularClientMixin

  def initialize(ext_management_system, tenant = '_system')
    @ext_management_system = ext_management_system
    @tenant = tenant
  end

  delegate :gauges, :to => :hawkular_client
end
