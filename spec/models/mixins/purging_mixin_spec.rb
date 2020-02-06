RSpec.describe PurgingMixin do
  let(:example_class) { PolicyEvent }
  let(:purge_date) { 2.weeks.ago }

  describe ".purge_date" do
    it "purge_date should not raise exception" do
      stub_settings(:policy_events => {:history => {:keep_policy_events => 120}})
      expect(example_class.purge_date).to be_within(1.second).of(120.seconds.ago.utc)
    end
  end

  describe ".purge_mode_and_value" do
    it "purge_mode_and_value should return proper options" do
      stub_settings(:policy_events => {:history => {:keep_policy_events => 120}})
      expect(example_class.purge_mode_and_value.first).to eq(:date)
      expect(example_class.purge_mode_and_value.last).to be_within(1.second).of(120.seconds.ago.utc)
    end
  end

  describe ".purge" do
    let(:events) do
      (-2..2).collect do |date_modifier|
        FactoryBot.create(:policy_event, :timestamp => purge_date + date_modifier.days)
      end
    end
    let(:all_ids) { events.collect(&:id) }

    it "with no records" do
      expect(example_class.purge(purge_date)).to eq(0)
    end

    it "with a date out of range" do
      events # create events
      expect(example_class.purge(6.months.ago)).to eq(0)
      expect(example_class.pluck(:id)).to match_array(all_ids)
    end

    it "with a date out of range" do
      events # create events
      allow(example_class).to receive(:purge_date).and_return(6.months.ago)
      expect(example_class.purge).to eq(0)
      expect(example_class.pluck(:id)).to match_array(all_ids)
    end

    it "with a date within range" do
      events # create events
      expect(example_class.purge(purge_date + 1.second)).to eq(3)
      expect(example_class.pluck(:id)).to match_array all_ids.last(2)
    end

    it "with a date within range from configuration" do
      events # create events
      allow(example_class).to receive(:purge_date).and_return(purge_date + 1.second)
      expect(example_class.purge).to eq(3)
      expect(example_class.pluck(:id)).to match_array all_ids.last(2)
    end

    it "with a date covering the whole range" do
      events # create events
      expect(example_class.purge(Time.now.utc)).to eq(5)
      expect(example_class.pluck(:id)).to match_array []
    end

    it "with a date covering the whole range from configuration" do
      events # create events
      allow(example_class).to receive(:purge_date).and_return(Time.now)
      expect(example_class.purge(Time.now.utc)).to eq(5)
      expect(example_class.pluck(:id)).to match_array []
    end

    it "with a date and a window" do
      events # create events
      expect(example_class.purge(purge_date + 1.second, 2)).to eq(3)
      expect(example_class.pluck(:id)).to match_array all_ids.last(2)
    end

    it "with a date and a window from configuration" do
      events # create events
      allow(example_class).to receive(:purge_date).and_return(purge_date + 1.second)
      allow(example_class).to receive(:purge_window_size).and_return(2)
      expect(example_class.purge).to eq(3)
      expect(example_class.pluck(:id)).to match_array all_ids.last(2)
    end
  end
end
