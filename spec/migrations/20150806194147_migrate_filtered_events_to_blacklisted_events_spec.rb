require 'spec_helper'
require Rails.root.join('db/migrate/20150806194147_migrate_filtered_events_to_blacklisted_events.rb')

describe MigrateFilteredEventsToBlacklistedEvents do
  let(:configuration_stub)     { migration_stub(:Configuration) }

  migration_context :up do
    it 'when filtered events section exists with system events' do
      event_settings = {
        'filtered_events' => {
          :AlarmActionTriggeredEvent => nil,
          :AlarmCreatedEvent         => nil
        }
      }
      configuration_stub.create!(:typ => 'event_handling', :settings => event_settings)

      migrate

      expect(Configuration.first.settings.fetch_path('filtered_events')).to be_blank
      expect(BlacklistedEvent.count).to eq(0)
    end

    it 'when filtered events section exists with user added events' do
      event_settings = {
        'filtered_events' => {
          :SomeNewEvent => nil
        }
      }
      configuration_stub.create!(:typ => 'event_handling', :settings => event_settings)

      migrate

      expect(Configuration.first.settings.fetch_path('filtered_events')).to be_blank
      expect(BlacklistedEvent.count).to eq(MigrateFilteredEventsToBlacklistedEvents::PROVIDER_NAMES.size)
    end

    it 'when filtered events section does not exist in configuration' do
      configuration_stub.create!(:typ => 'event_handling', :settings => {:event_groups => {'a' => nil }})

      migrate

      expect(Configuration.first.settings.fetch_path('filtered_events')).to be_blank
      expect(BlacklistedEvent.count).to eq(0)
    end

    it 'when event handling configuration does not exist' do
      migrate

      expect(BlacklistedEvent.count).to eq(0)
    end

    it 'when multiple event handling configurations exist' do
      configuration_stub.create!(:typ => 'event_handling', :settings => { 'filtered_events' => { :user_event_1 => nil } })
      configuration_stub.create!(:typ => 'event_handling', :settings => { 'filtered_events' => { :user_event_2 => nil } })

      migrate

      expect(Configuration.first.settings.fetch_path('filtered_events')).to be_blank
      expect(BlacklistedEvent.count).to eq(2 * MigrateFilteredEventsToBlacklistedEvents::PROVIDER_NAMES.size)
    end
  end
end
