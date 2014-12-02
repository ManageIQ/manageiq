require "spec_helper"

describe PurgingMixin do
  describe ".purge" do
    let(:example_class) { PolicyEvent }
    let(:example_associated_class) { PolicyEventContent }
    let(:purge_date) { 2.weeks.ago }

    before do
      events = (-2..2).collect do |date_modifier|
        FactoryGirl.create(:policy_event, :timestamp => purge_date + date_modifier.days)
      end
      @unpurged_ids = events[-2, 2].collect(&:id)
    end

    it "with a date out of range" do
      expect(example_class).to receive(:delete_all).never
      expect(example_associated_class).to receive(:delete_all).never
      example_class.purge(6.months.ago)
    end

    it "with a date out of range from configuration" do
      allow(example_class).to receive(:purge_date).and_return(6.months.ago)

      expect(example_class).to receive(:delete_all).never
      expect(example_associated_class).to receive(:delete_all).never
      example_class.purge
    end

    it "with a date within range" do
      expect(example_class).to receive(:delete_all).once.and_call_original
      expect(example_associated_class).to receive(:delete_all).once.and_call_original
      example_class.purge(purge_date + 1.second)
      expect(example_class.pluck(:id)).to match_array @unpurged_ids
    end

    it "with a date within range from configuration" do
      allow(example_class).to receive(:purge_date).and_return(purge_date + 1.second)

      expect(example_class).to receive(:delete_all).once.and_call_original
      expect(example_associated_class).to receive(:delete_all).once.and_call_original
      example_class.purge
      expect(example_class.pluck(:id)).to match_array @unpurged_ids
    end

    it "with a date covering the whole range" do
      expect(example_class).to receive(:delete_all).once.and_call_original
      expect(example_associated_class).to receive(:delete_all).once.and_call_original
      example_class.purge(Time.now)
      expect(example_class.pluck(:id)).to match_array []
    end

    it "with a date covering the whole range from configuration" do
      allow(example_class).to receive(:purge_date).and_return(Time.now)

      expect(example_class).to receive(:delete_all).once.and_call_original
      expect(example_associated_class).to receive(:delete_all).once.and_call_original
      example_class.purge
      expect(example_class.pluck(:id)).to match_array []
    end

    it "with a date and a window" do
      expect(example_class).to receive(:delete_all).twice.and_call_original
      expect(example_associated_class).to receive(:delete_all).twice.and_call_original
      example_class.purge(purge_date + 1.second, 2)
      expect(example_class.pluck(:id)).to match_array @unpurged_ids
    end

    it "with a date and a window from configuration" do
      allow(example_class).to receive(:purge_date).and_return(purge_date + 1.second)
      allow(example_class).to receive(:purge_window_size).and_return(2)

      expect(example_class).to receive(:delete_all).twice.and_call_original
      expect(example_associated_class).to receive(:delete_all).twice.and_call_original
      example_class.purge
      expect(example_class.pluck(:id)).to match_array @unpurged_ids
    end
  end
end
