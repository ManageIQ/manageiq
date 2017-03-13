class ManageIQ::Providers::Hawkular::DatawarehouseManager::EventCatcher::Runner <
  ManageIQ::Providers::BaseManager::EventCatcher::Runner

  include ManageIQ::Providers::Hawkular::Common::EventCatcher::RunnerMixin

  TAG_URL  = 'url'.freeze
  TAG_TYPE = 'type'.freeze

  def initialize(cfg = {})
    super
  end

  def self.log_handle
    $datawarehouse_log
  end

  def self.event_monitor_class
    ManageIQ::Providers::Hawkular::DatawarehouseManager::EventCatcher::Stream
  end

  def self.find_target(tags)
    target = case tags[TAG_TYPE].downcase
             when "node" then OpenStruct.new(
               :klass_name     => 'ContainerNode',
               :find_key       => :name,
               :value_tag_name => 'nodename',
             )
             else
               $datawarehouse_log.error("unexpected target: [#{tags[TAG_TYPE]}]")
               nil
             end
    instance = nil
    instance = target.klass_name.constantize.find_by(target.find_key => tags[target.value_tag_name]) if target
    $datawarehouse_log.error("Could not find hawkular alert target from tags: [#{tags}]") unless instance
    instance
  end

  private

  def whitelisted?(_event)
    true # we collect event by tags, see stream
  end

  def event_to_hash(event, current_ems_id)
    event = event.dup
    event.severity = map_severity(event.severity) # gets into event.full_data
    event.url = event.tags[TAG_URL]
    event.ems_ref = event.id
    event.resolved = event.status == "RESOLVED"
    timestamp = event.resolved ? event.lifecycle.last['stime'] : event.ctime
    target = self.class.find_target(event.tags)
    {
      :ems_id              => target.try(:ext_management_system).try(:id),
      :generating_ems_id   => current_ems_id,
      :source              => 'DATAWAREHOUSE',
      :timestamp           => Time.zone.at(timestamp / 1000),
      :event_type          => 'datawarehouse_alert',
      :target_type         => target.class.name.underscore,
      :target_id           => target.id,
      :container_node_id   => target.id,
      :container_node_name => target.name,
      :message             => event.text,
      :full_data           => event.to_h
    }
  end

  def map_severity(hwk_severity)
    case hwk_severity
    when "LOW"      then 'info'
    when "MEDIUM"   then 'warning'
    when "HIGH"     then 'warning'
    when "CRITICAL" then 'error'
    else
      $datawarehouse_log.error("Could not map hawkular severity [#{hwk_severity}], using error")
      'error'
    end
  end
end
