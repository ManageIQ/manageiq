describe LiveMetricsMixin do
  subject do
    Class.new do
      include LiveMetricsMixin
    end.new
  end

  context "#adjust_timestamps" do
    it "doesn't change the output when the interval is not hourly" do
      now = Time.now
      firsts = [now.to_i * 1000]
      lasts = [now.to_i * 1000]

      result = subject.adjust_timestamps(firsts, lasts, nil)

      expect(result.first).to be_within(1).of(now.utc)
      expect(result.last).to be_within(1).of(now.utc)
    end

    context "when the interval is not hourly" do
      it "when the first time is less than an hour" do
        now = Time.now
        firsts = [now.to_i * 1000]
        lasts = [now.to_i * 1000]

        result = subject.adjust_timestamps(firsts, lasts, "hourly")

        expect(result.first).to be_nil
        expect(result.last).to be_within(1).of(now.utc)
      end

      it "when the first time is more than an hour ago" do
        now = Time.now
        firsts = [(now - 2.hours).to_i * 1000]
        lasts = [now.to_i * 1000]

        result = subject.adjust_timestamps(firsts, lasts, "hourly")

        expect(result.first).to be_within(1).of(now.utc - 2.hours)
        expect(result.last).to be_within(1).of(now.utc)
      end
    end
  end
end
