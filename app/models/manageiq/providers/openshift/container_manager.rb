class ManageIQ::Providers::Openshift::ContainerManager < ManageIQ::Providers::ContainerManager
  include ManageIQ::Providers::Openshift::ContainerManagerMixin

  require_nested :EventCatcher
  require_nested :EventCatcherHawkular
  require_nested :EventParser
  require_nested :MetricsCollectorWorker
  require_nested :RefreshParser
  require_nested :RefreshWorker
  require_nested :Refresher

  def self.ems_type
    @ems_type ||= "openshift".freeze
  end

  def self.description
    @description ||= "OpenShift Origin".freeze
  end

  def self.event_monitor_class
    #byebug_term
    #ManageIQ::Providers::Openshift::ContainerManager::EventCatcher
    ManageIQ::Providers::Openshift::ContainerManager::EventCatcherHawkular
    #ManageIQ::Providers::Hawkular::MiddlewareManager::EventCatcher
  end

  def alerts_client
    #byebug_term
    connection = ManageIQ::Providers::Hawkular::MiddlewareManager.raw_connect(
      'mtayer-centos7-5.eng.lab.tlv.redhat.com', 8080, 'jdoe', 'password')
    connection.alerts
  end

  def supported_auth_attributes
    %w(userid password auth_key)
  end
end
