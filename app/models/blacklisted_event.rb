class BlacklistedEvent < ApplicationRecord
  belongs_to        :ext_management_system, :foreign_key => "ems_id"

  default_value_for :enabled, true
  after_save        :reload_all_server_settings
  after_destroy     :reload_all_server_settings, :audit_deletion
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

  def reload_all_server_settings
    MiqRegion.my_region.reload_all_server_settings
  end
end
