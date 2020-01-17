require 'workers/event_catcher'

RSpec.describe BlacklistedEvent do
  let(:total_blacklist_entry_count) { ExtManagementSystem.descendants.collect(&:default_blacklisted_event_names).flatten.count }
  before do
    MiqRegion.seed
  end

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

  it '#enabled=' do
    User.current_user = FactoryBot.create(:user)
    f = FactoryBot.create(:blacklisted_event, :event_name => 'event_1')
    expect(f.enabled).to be_truthy

    f.enabled = false
    expect(f.enabled).to be_falsey
  end
end
