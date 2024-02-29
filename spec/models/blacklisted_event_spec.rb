require 'workers/event_catcher'

RSpec.describe BlacklistedEvent do
  let(:total_blacklist_entry_count) { ExtManagementSystem.descendants.collect(&:default_blacklisted_event_names).flatten.count }
  context '.seed' do
    it 'loads event filters' do
      described_class.seed
      expect(described_class.count).to eq(total_blacklist_entry_count)
    end

    it 're-seeds deleted event filters' do
      described_class.seed
      described_class.where(:event_name => 'AlarmCreatedEvent').destroy_all
      expect(described_class.count).to eq(total_blacklist_entry_count - 1)

      described_class.seed
      expect(described_class.count).to eq(total_blacklist_entry_count)
    end

    it 'does not re-seed existing event filters' do
      User.current_user = FactoryBot.create(:user)
      filter = FactoryBot.create(:blacklisted_event,
                                 :event_name     => 'AlarmActionTriggeredEvent',
                                 :provider_model => 'ManageIQ::Providers::Vmware::InfraManager'
                                )
      filter_attrs = filter.attributes

      described_class.seed
      expect(filter.attributes).to eq(filter_attrs)
    end
  end

  context "#enabled=" do
    it 'new record' do
      f = FactoryBot.create(:blacklisted_event, :event_name => 'event_1')
      expect(f.enabled).to be_truthy

      f.enabled = false
      expect(f.enabled).to be_falsey
    end

    it 'persisted' do
      f = FactoryBot.build(:blacklisted_event, :event_name => 'event_1')
      expect(f.enabled).to be_truthy

      f.enabled = false
      expect(f.enabled).to be_falsey
    end

    it "log creation" do
      expect($audit_log).to receive(:info).with(a_string_including("Creating")).once
      FactoryBot.create(:blacklisted_event, :event_name => 'event_1')
    end

    it "doesn't log changed on creation" do
      expect($audit_log).to receive(:info).with(a_string_including("changed")).never
      FactoryBot.create(:blacklisted_event, :event_name => 'event_1')
    end

    it 'logs a message when changed' do
      f = FactoryBot.create(:blacklisted_event, :event_name => 'event_1')

      expect($audit_log).to receive(:info).with(a_string_including("changed")).once
      f.update(:enabled => false)
    end

    it 'does not log a message when unchanged' do
      f = FactoryBot.create(:blacklisted_event, :event_name => 'event_1')

      expect($audit_log).to receive(:info).with(a_string_including("changed")).never
      f.update(:enabled => f.enabled)
    end
  end
end
