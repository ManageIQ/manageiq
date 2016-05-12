RSpec.describe MiqExpression::RelativeDatetime do
  describe ".normalize" do
    context "Testing expression conversion to ruby with relative dates and times" do
      around { |example| Timecop.freeze("2011-01-11 17:30 UTC") { example.run } }

      it "does something" do
        # Test <value> <interval> Ago
        expect(described_class.normalize("3 Hours Ago", "Eastern Time (US & Canada)").utc.to_s).to eq("2011-01-11 14:00:00 UTC")
        expect(described_class.normalize("3 Hours Ago", "UTC").utc.to_s).to eq("2011-01-11 14:00:00 UTC")
        expect(described_class.normalize("3 Hours Ago", "UTC", "end").utc.to_s).to eq("2011-01-11 14:59:59 UTC")

        expect(described_class.normalize("3 Days Ago", "Eastern Time (US & Canada)").utc.to_s).to eq("2011-01-08 05:00:00 UTC")
        expect(described_class.normalize("3 Days Ago", "UTC").utc.to_s).to eq("2011-01-08 00:00:00 UTC")
        expect(described_class.normalize("3 Days Ago", "UTC", "end").utc.to_s).to eq("2011-01-08 23:59:59 UTC")

        expect(described_class.normalize("3 Weeks Ago", "Eastern Time (US & Canada)").utc.to_s).to eq("2010-12-20 05:00:00 UTC")
        expect(described_class.normalize("3 Weeks Ago", "UTC").utc.to_s).to eq("2010-12-20 00:00:00 UTC")

        expect(described_class.normalize("4 Months Ago", "Eastern Time (US & Canada)").utc.to_s).to eq("2010-09-01 04:00:00 UTC")
        expect(described_class.normalize("4 Months Ago", "UTC").utc.to_s).to eq("2010-09-01 00:00:00 UTC")
        expect(described_class.normalize("4 Months Ago", "UTC", "end").utc.to_s).to eq("2010-09-30 23:59:59 UTC")

        expect(described_class.normalize("1 Quarter Ago", "Eastern Time (US & Canada)").utc.to_s).to eq("2010-10-01 04:00:00 UTC")
        expect(described_class.normalize("1 Quarter Ago", "UTC").utc.to_s).to eq("2010-10-01 00:00:00 UTC")
        expect(described_class.normalize("1 Quarter Ago", "UTC", "end").utc.to_s).to eq("2010-12-31 23:59:59 UTC")

        expect(described_class.normalize("3 Quarters Ago", "Eastern Time (US & Canada)").utc.to_s).to eq("2010-04-01 04:00:00 UTC")
        expect(described_class.normalize("3 Quarters Ago", "UTC").utc.to_s).to eq("2010-04-01 00:00:00 UTC")
        expect(described_class.normalize("3 Quarters Ago", "UTC", "end").utc.to_s).to eq("2010-06-30 23:59:59 UTC")

        # Test Now, Today, Yesterday
        expect(described_class.normalize("Now", "Eastern Time (US & Canada)").utc.to_s).to eq("2011-01-11 17:00:00 UTC")
        expect(described_class.normalize("Now", "UTC").utc.to_s).to eq("2011-01-11 17:00:00 UTC")
        expect(described_class.normalize("Now", "UTC", "end").utc.to_s).to eq("2011-01-11 17:59:59 UTC")

        expect(described_class.normalize("Today", "Eastern Time (US & Canada)").utc.to_s).to eq("2011-01-11 05:00:00 UTC")
        expect(described_class.normalize("Today", "UTC").utc.to_s).to eq("2011-01-11 00:00:00 UTC")
        expect(described_class.normalize("Today", "UTC", "end").utc.to_s).to eq("2011-01-11 23:59:59 UTC")

        expect(described_class.normalize("Yesterday", "Eastern Time (US & Canada)").utc.to_s).to eq("2011-01-10 05:00:00 UTC")
        expect(described_class.normalize("Yesterday", "UTC").utc.to_s).to eq("2011-01-10 00:00:00 UTC")
        expect(described_class.normalize("Yesterday", "UTC", "end").utc.to_s).to eq("2011-01-10 23:59:59 UTC")

        # Test Last ...
        expect(described_class.normalize("Last Hour", "Eastern Time (US & Canada)").utc.to_s).to eq("2011-01-11 16:00:00 UTC")
        expect(described_class.normalize("Last Hour", "UTC").utc.to_s).to eq("2011-01-11 16:00:00 UTC")
        expect(described_class.normalize("Last Hour", "UTC", "end").utc.to_s).to eq("2011-01-11 16:59:59 UTC")

        expect(described_class.normalize("Last Week", "Eastern Time (US & Canada)").utc.to_s).to eq("2011-01-03 05:00:00 UTC")
        expect(described_class.normalize("Last Week", "UTC").utc.to_s).to eq("2011-01-03 00:00:00 UTC")
        expect(described_class.normalize("Last Week", "UTC", "end").utc.to_s).to eq("2011-01-09 23:59:59 UTC")

        expect(described_class.normalize("Last Month", "Eastern Time (US & Canada)").utc.to_s).to eq("2010-12-01 05:00:00 UTC")
        expect(described_class.normalize("Last Month", "UTC").utc.to_s).to eq("2010-12-01 00:00:00 UTC")
        expect(described_class.normalize("Last Month", "UTC", "end").utc.to_s).to eq("2010-12-31 23:59:59 UTC")

        expect(described_class.normalize("Last Quarter", "Eastern Time (US & Canada)").utc.to_s).to eq("2010-10-01 04:00:00 UTC")
        expect(described_class.normalize("Last Quarter", "UTC").utc.to_s).to eq("2010-10-01 00:00:00 UTC")
        expect(described_class.normalize("Last Quarter", "UTC", "end").utc.to_s).to eq("2010-12-31 23:59:59 UTC")

        # Test This ...
        expect(described_class.normalize("This Hour", "Eastern Time (US & Canada)").utc.to_s).to eq("2011-01-11 17:00:00 UTC")
        expect(described_class.normalize("This Hour", "UTC").utc.to_s).to eq("2011-01-11 17:00:00 UTC")
        expect(described_class.normalize("This Hour", "UTC", "end").utc.to_s).to eq("2011-01-11 17:59:59 UTC")

        expect(described_class.normalize("This Week", "Eastern Time (US & Canada)").utc.to_s).to eq("2011-01-10 05:00:00 UTC")
        expect(described_class.normalize("This Week", "UTC").utc.to_s).to eq("2011-01-10 00:00:00 UTC")
        expect(described_class.normalize("This Week", "UTC", "end").utc.to_s).to eq("2011-01-16 23:59:59 UTC")

        expect(described_class.normalize("This Month", "Eastern Time (US & Canada)").utc.to_s).to eq("2011-01-01 05:00:00 UTC")
        expect(described_class.normalize("This Month", "UTC").utc.to_s).to eq("2011-01-01 00:00:00 UTC")
        expect(described_class.normalize("This Month", "UTC", "end").utc.to_s).to eq("2011-01-31 23:59:59 UTC")

        expect(described_class.normalize("This Quarter", "Eastern Time (US & Canada)").utc.to_s).to eq("2011-01-01 05:00:00 UTC")
        expect(described_class.normalize("This Quarter", "UTC").utc.to_s).to eq("2011-01-01 00:00:00 UTC")
        expect(described_class.normalize("This Quarter", "UTC", "end").utc.to_s).to eq("2011-03-31 23:59:59 UTC")
      end
    end
  end
end
