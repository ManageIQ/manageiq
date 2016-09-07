RSpec.describe MiqExpression::RelativeDatetime do
  describe ".normalize" do
    around { |example| Timecop.freeze("2011-01-11 17:30 UTC") { example.run } }

    context "n Hours Ago" do
      it "non-UTC" do
        result = described_class.normalize("3 Hours Ago", "Eastern Time (US & Canada)")
        expect(result).to eq("2011-01-11 14:00:00 UTC")
      end

      it "UTC" do
        result = described_class.normalize("3 Hours Ago", "UTC")
        expect(result).to eq("2011-01-11 14:00:00 UTC")
      end

      it "end mode" do
        result = described_class.normalize("3 Hours Ago", "UTC", "end")
        expect(result).to eq("2011-01-11 14:59:59.999999999 UTC")
      end
    end

    context "n Days Ago" do
      it "non-UTC" do
        result = described_class.normalize("3 Days Ago", "Eastern Time (US & Canada)")
        expect(result).to eq("2011-01-08 05:00:00 UTC")
      end

      it "UTC" do
        result = described_class.normalize("3 Days Ago", "UTC")
        expect(result).to eq("2011-01-08 00:00:00 UTC")
      end

      it "end mode" do
        result = described_class.normalize("3 Days Ago", "UTC", "end")
        expect(result).to eq("2011-01-08 23:59:59.999999999 UTC")
      end
    end

    context "n Weeks Ago" do
      it "non-UTC" do
        result = described_class.normalize("3 Weeks Ago", "Eastern Time (US & Canada)")
        expect(result).to eq("2010-12-20 05:00:00 UTC")
      end

      it "UTC" do
        result = described_class.normalize("3 Weeks Ago", "UTC")
        expect(result).to eq("2010-12-20 00:00:00 UTC")
      end
    end

    context "n Months Ago" do
      it "non-UTC" do
        result = described_class.normalize("4 Months Ago", "Eastern Time (US & Canada)")
        expect(result).to eq("2010-09-01 04:00:00 UTC")
      end

      it "UTC" do
        result = described_class.normalize("4 Months Ago", "UTC")
        expect(result).to eq("2010-09-01 00:00:00 UTC")
      end

      it "end mode" do
        result = described_class.normalize("4 Months Ago", "UTC", "end")
        expect(result).to eq("2010-09-30 23:59:59.999999999 UTC")
      end
    end

    context "1 Quarter Ago" do
      it "non-UTC" do
        result = described_class.normalize("1 Quarter Ago", "Eastern Time (US & Canada)")
        expect(result).to eq("2010-10-01 04:00:00 UTC")
      end

      it "UTC" do
        result = described_class.normalize("1 Quarter Ago", "UTC")
        expect(result).to eq("2010-10-01 00:00:00 UTC")
      end

      it "end mode" do
        result = described_class.normalize("1 Quarter Ago", "UTC", "end")
        expect(result).to eq("2010-12-31 23:59:59.999999999 UTC")
      end
    end

    context "n Quarters Ago" do
      it "non-UTC" do
        result = described_class.normalize("3 Quarters Ago", "Eastern Time (US & Canada)")
        expect(result).to eq("2010-04-01 04:00:00 UTC")
      end

      it "UTC" do
        result = described_class.normalize("3 Quarters Ago", "UTC")
        expect(result).to eq("2010-04-01 00:00:00 UTC")
      end

      it "end mode" do
        result = described_class.normalize("3 Quarters Ago", "UTC", "end")
        expect(result).to eq("2010-06-30 23:59:59.999999999 UTC")
      end
    end

    context "Now" do
      it "non-UTC" do
        result = described_class.normalize("Now", "Eastern Time (US & Canada)")
        expect(result).to eq("2011-01-11 17:00:00 UTC")
      end

      it "UTC" do
        result = described_class.normalize("Now", "UTC")
        expect(result).to eq("2011-01-11 17:00:00 UTC")
      end

      it "end mode" do
        result = described_class.normalize("Now", "UTC", "end")
        expect(result).to eq("2011-01-11 17:59:59.999999999 UTC")
      end
    end

    context "Today" do
      it "non-UTC" do
        result = described_class.normalize("Today", "Eastern Time (US & Canada)")
        expect(result).to eq("2011-01-11 05:00:00 UTC")
      end

      it "UTC" do
        result = described_class.normalize("Today", "UTC")
        expect(result).to eq("2011-01-11 00:00:00 UTC")
      end

      it "end mode" do
        result = described_class.normalize("Today", "UTC", "end")
        expect(result).to eq("2011-01-11 23:59:59.999999999 UTC")
      end
    end

    context "Yesterday" do
      it "non-UTC" do
        result = described_class.normalize("Yesterday", "Eastern Time (US & Canada)")
        expect(result).to eq("2011-01-10 05:00:00 UTC")
      end

      it "UTC" do
        result = described_class.normalize("Yesterday", "UTC")
        expect(result).to eq("2011-01-10 00:00:00 UTC")
      end

      it "end mode" do
        result = described_class.normalize("Yesterday", "UTC", "end")
        expect(result).to eq("2011-01-10 23:59:59.999999999 UTC")
      end
    end

    context "Last Hour" do
      it "non-UTC" do
        result = described_class.normalize("Last Hour", "Eastern Time (US & Canada)")
        expect(result).to eq("2011-01-11 16:00:00 UTC")
      end

      it "UTC" do
        result = described_class.normalize("Last Hour", "UTC")
        expect(result).to eq("2011-01-11 16:00:00 UTC")
      end

      it "end mode" do
        result = described_class.normalize("Last Hour", "UTC", "end")
        expect(result).to eq("2011-01-11 16:59:59.999999999 UTC")
      end
    end

    context "Last Week" do
      it "non-UTC" do
        result = described_class.normalize("Last Week", "Eastern Time (US & Canada)")
        expect(result).to eq("2011-01-03 05:00:00 UTC")
      end

      it "UTC" do
        result = described_class.normalize("Last Week", "UTC")
        expect(result).to eq("2011-01-03 00:00:00 UTC")
      end

      it "end mode" do
        result = described_class.normalize("Last Week", "UTC", "end")
        expect(result).to eq("2011-01-09 23:59:59.999999999 UTC")
      end
    end

    context "Last Month" do
      it "non-UTC" do
        result = described_class.normalize("Last Month", "Eastern Time (US & Canada)")
        expect(result).to eq("2010-12-01 05:00:00 UTC")
      end

      it "UTC" do
        result = described_class.normalize("Last Month", "UTC")
        expect(result).to eq("2010-12-01 00:00:00 UTC")
      end

      it "end mode" do
        result = described_class.normalize("Last Month", "UTC", "end")
        expect(result).to eq("2010-12-31 23:59:59.999999999 UTC")
      end
    end

    context "Last Quarter" do
      it "non-UTC" do
        result = described_class.normalize("Last Quarter", "Eastern Time (US & Canada)")
        expect(result).to eq("2010-10-01 04:00:00 UTC")
      end

      it "UTC" do
        result = described_class.normalize("Last Quarter", "UTC")
        expect(result).to eq("2010-10-01 00:00:00 UTC")
      end

      it "end mode" do
        result = described_class.normalize("Last Quarter", "UTC", "end")
        expect(result).to eq("2010-12-31 23:59:59.999999999 UTC")
      end
    end

    context "This Hour" do
      it "non-UTC" do
        result = described_class.normalize("This Hour", "Eastern Time (US & Canada)")
        expect(result).to eq("2011-01-11 17:00:00 UTC")
      end

      it "UTC" do
        result = described_class.normalize("This Hour", "UTC")
        expect(result).to eq("2011-01-11 17:00:00 UTC")
      end

      it "end mode" do
        result = described_class.normalize("This Hour", "UTC", "end")
        expect(result).to eq("2011-01-11 17:59:59.999999999 UTC")
      end
    end

    context "This Week" do
      it "non-UTC" do
        result = described_class.normalize("This Week", "Eastern Time (US & Canada)")
        expect(result).to eq("2011-01-10 05:00:00 UTC")
      end

      it "UTC" do
        result = described_class.normalize("This Week", "UTC")
        expect(result).to eq("2011-01-10 00:00:00 UTC")
      end

      it "end mode" do
        result = described_class.normalize("This Week", "UTC", "end")
        expect(result).to eq("2011-01-16 23:59:59.999999999 UTC")
      end
    end

    context "This Month" do
      it "non-UTC" do
        result = described_class.normalize("This Month", "Eastern Time (US & Canada)")
        expect(result).to eq("2011-01-01 05:00:00 UTC")
      end

      it "UTC" do
        result = described_class.normalize("This Month", "UTC")
        expect(result).to eq("2011-01-01 00:00:00 UTC")
      end

      it "end mode" do
        result = described_class.normalize("This Month", "UTC", "end")
        expect(result).to eq("2011-01-31 23:59:59.999999999 UTC")
      end
    end

    context "This Quarter" do
      it "non-UTC" do
        result = described_class.normalize("This Quarter", "Eastern Time (US & Canada)")
        expect(result).to eq("2011-01-01 05:00:00 UTC")
      end

      it "UTC" do
        result = described_class.normalize("This Quarter", "UTC")
        expect(result).to eq("2011-01-01 00:00:00 UTC")
      end

      it "end mode" do
        result = described_class.normalize("This Quarter", "UTC", "end")
        expect(result).to eq("2011-03-31 23:59:59.999999999 UTC")
      end
    end
  end
end
