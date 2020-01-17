RSpec.describe EventMixin do
  context "Included in a test class with events" do
    let(:test_class) do
      Class.new do
        include SupportsFeatureMixin
        include EventMixin

        def event_where_clause(assoc)
          ["#{events_table_name(assoc)}.ems_id = ?", 1]
        end
      end
    end

    before do
      @ts_1 = 5.days.ago
      FactoryBot.create(:ems_event, :ems_id => 1, :timestamp => @ts_1)
      @ts_2 = 4.days.ago
      FactoryBot.create(:ems_event, :ems_id => 1, :timestamp => @ts_2)
      @ts_3 = 3.days.ago
      FactoryBot.create(:ems_event, :ems_id => 1, :timestamp => @ts_3)
    end

    it "#first_event" do
      expect(test_class.new.first_event).to be_within(0.1).of @ts_1
    end

    it "#last_event" do
      expect(test_class.new.last_event).to  be_within(0.1).of @ts_3
    end

    it "#first_and_last_event" do
      events = test_class.new.first_and_last_event
      expect(events.length).to eq(2)
      expect(events[0]).to     be_within(0.1).of @ts_1
      expect(events[1]).to     be_within(0.1).of @ts_3
    end

    it "#has_events?" do
      expect(test_class.new).to have_events
    end
  end

  context "Included in a test class with no events" do
    let(:test_class) do
      Class.new do
        include SupportsFeatureMixin
        include EventMixin

        def event_where_clause(assoc)
          ["#{events_table_name(assoc)}.ems_id = ?", nil]
        end
      end
    end

    it "#first_event" do
      expect(test_class.new.first_event).to be_nil
    end

    it "#last_event" do
      expect(test_class.new.last_event).to  be_nil
    end

    it "#first_and_last_event" do
      expect(test_class.new.first_and_last_event).to be_empty
    end

    it "#has_events?" do
      expect(test_class.new).not_to have_events
    end
  end
end
