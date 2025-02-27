RSpec.describe ManageIQ::Providers::BaseManager do
  context ".filtered_event_names" do
    it 'returns an empty array for the base class' do
      expect(described_class.filtered_event_names).to eq([])
    end

    it 'returns the provider event if configured' do
      stub_settings_merge(
        :ems => {
          :ems_some_provider => {
            :blacklisted_event_names => %w[ev1 ev2]
          }
        }
      )
      allow(described_class).to receive(:ems_type).and_return(:some_provider)
      expect(described_class.filtered_event_names).to eq(%w[ev1 ev2])
    end
  end

  context ".url" do
    it 'delegates to the provider' do
      mgr = FactoryBot.create(:configuration_manager_foreman, :provider => FactoryBot.create(:provider_foreman, :url => 'example.com'))
      expect(mgr.url).to eq('example.com')
    end
  end
end
