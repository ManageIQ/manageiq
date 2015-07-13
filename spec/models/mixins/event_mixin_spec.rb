require "spec_helper"

describe EventMixin do
  context "Included in a test class with events" do
    before do
      class TestClass
        include EventMixin

        def event_where_clause(assoc)
          ["ems_id = ?", 1]
        end
      end

      @ts_1 = 5.days.ago
      FactoryGirl.create(:ems_event, :ems_id => 1, :timestamp => @ts_1)
      @ts_2 = 4.days.ago
      FactoryGirl.create(:ems_event, :ems_id => 1, :timestamp => @ts_2)
      @ts_3 = 3.days.ago
      FactoryGirl.create(:ems_event, :ems_id => 1, :timestamp => @ts_3)
    end

    after do
      Object.send(:remove_const, "TestClass")
    end

    it "#first_event" do
      TestClass.new.first_event.should be_same_time_as @ts_1
    end

    it "#last_event" do
      TestClass.new.last_event.should  be_same_time_as @ts_3
    end

    it "#first_and_last_event" do
      events = TestClass.new.first_and_last_event
      events.length.should == 2
      events[0].should     be_same_time_as @ts_1
      events[1].should     be_same_time_as @ts_3
    end

    it "#has_events?" do
      TestClass.new.should have_events
    end
  end

  context "Included in a test class with no events" do
    before do
      class TestClass
        include EventMixin

        def event_where_clause(assoc)
          ["ems_id = ?", nil]
        end
      end
    end

    after do
      Object.send(:remove_const, "TestClass")
    end

    it "#first_event" do
      TestClass.new.first_event.should be_nil
    end

    it "#last_event" do
      TestClass.new.last_event.should  be_nil
    end

    it "#first_and_last_event" do
      TestClass.new.first_and_last_event.should be_empty
    end

    it "#has_events?" do
      TestClass.new.should_not have_events
    end
  end

end
