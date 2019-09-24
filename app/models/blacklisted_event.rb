class BlacklistedEvent < ApplicationRecord
  belongs_to        :ext_management_system, :foreign_key => "ems_id"

  default_value_for :enabled, true
  after_save        :queue_sync_blacklisted_event_names
  after_destroy     :queue_sync_blacklisted_event_names, :audit_deletion
  after_create      :audit_creation

  def audit_deletion
    $audit_log.info("Blacklisted event [#{event_name}] for provider [#{provider_model}] with ID [#{ems_id}] has been deleted by user [#{self.class.current_userid}]")
  end

  def audit_creation
    $audit_log.info("Creating blacklisted event [#{event_name}] for provider [#{provider_model}] with ID [#{ems_id}] by user [#{self.class.current_userid}]")
  end

  def enabled=(value)
    return if enabled == value

    super
    $audit_log.info("Blacklisted event [#{event_name}] for provider [#{provider_model}] with ID [#{ems_id}] had enabled changed to #{value} by user [#{self.class.current_userid}]")
  end

  def self.seed
    existing = where(:ems_id => nil).pluck(:provider_model, :event_name).group_by(&:first).each_with_object({}) { |(ems, q), res| res[ems] = q.map(&:last) }
    ExtManagementSystem.descendants.each do |ems|
      missing_events = ems.default_blacklisted_event_names - (existing[ems.name] || [])
      create!(missing_events.collect { |e| {:event_name => e, :provider_model => ems.name, :system => true} })
    end
  end

  def self.current_userid
    User.current_userid || 'system'
  end

  def queue_sync_blacklisted_event_names
    # notify MiqServer to sync with the blacklisted events
    servers = MiqRegion.my_region.active_miq_servers
    return if servers.blank?
    _log.info("Queueing sync_blacklisted_event_names for [#{servers.length}] active_miq_servers, ids: #{servers.collect(&:id)}")

    servers.each do |s|
      MiqQueue.put(
        :class_name  => "MiqServer",
        :instance_id => s.id,
        :method_name => "sync_blacklisted_event_names",
        :server_guid => s.guid,
        :priority    => MiqQueue::HIGH_PRIORITY,
        :queue_name  => 'miq_server'
      )
    end
  end
end
