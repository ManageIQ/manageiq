class ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::HawkularClient
  include ManageIQ::Providers::Kubernetes::ContainerManager::MetricsCapture::HawkularClientMixin

  def initialize(ext_management_system)
    @ext_management_system = ext_management_system
    @tenant = '_system'

    hawkular_client
  end
end
