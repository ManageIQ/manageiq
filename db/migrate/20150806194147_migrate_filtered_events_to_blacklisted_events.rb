class MigrateFilteredEventsToBlacklistedEvents < ActiveRecord::Migration
  class Configuration < ActiveRecord::Base
    serialize :settings
  end

  class BlacklistedEvent < ActiveRecord::Base; end

  def up
    say_with_time('Migrating filtered events from Configuration to BlacklistedEvent') do
      events = []
      Configuration.where(:typ => 'event_handling').each do |config|
        filtered_events = config.settings.fetch_path('filtered_events')
        next unless filtered_events

        events << filtered_events.each_with_object([]) { |(k, v), ary| ary << k.to_s if v.nil? }

        config.settings.delete_path('filtered_events')
        config.save
      end

      user_adds = events.flatten.uniq - default_blacklisted_event_names
      user_adds.each do |e|
        BlacklistedEvent.create!(PROVIDER_NAMES.collect { |p| {:event_name => e, :provider_model => p} })
      end
    end
  end

  private

  PROVIDER_NAMES = %w(
    ManageIQ::Providers::Openstack::CloudManager
    ManageIQ::Providers::Amazon::CloudManager
    ManageIQ::Providers::Redhat::InfraManager
    ManageIQ::Providers::Vmware::InfraManager
  )

  def default_blacklisted_event_names
    %w(
      scheduler.run_instance.start
      scheduler.run_instance.scheduled
      scheduler.run_instance.end
      ConfigurationSnapshotDeliveryCompleted
      ConfigurationSnapshotDeliveryStarted
      ConfigurationSnapshotDeliveryFailed
      UNASSIGNED
      USER_REMOVE_VG
      USER_REMOVE_VG_FAILED
      USER_VDC_LOGIN
      USER_VDC_LOGOUT
      USER_VDC_LOGIN_FAILED
      AlarmActionTriggeredEvent
      AlarmCreatedEvent
      AlarmEmailCompletedEvent
      AlarmEmailFailedEvent
      AlarmReconfiguredEvent
      AlarmRemovedEvent
      AlarmScriptCompleteEvent
      AlarmScriptFailedEvent
      AlarmSnmpCompletedEvent
      AlarmSnmpFailedEvent
      AlarmStatusChangedEvent
      AlreadyAuthenticatedSessionEvent
      EventEx
      UserLoginSessionEvent
      UserLogoutSessionEvent
    )
  end
end
