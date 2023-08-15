describe Chargeback::ReportOptions do
  describe "#group_by_tenant?" do
    it "detects groupby - true" do
      report_options = described_class.new_from_h(:groupby => "tenant")
      expect(report_options.group_by_tenant?).to eq(true)
    end
    it "detects groupby - false" do
      report_options = described_class.new_from_h(:groupby => "date")
      expect(report_options.group_by_tenant?).to eq(false)
    end
  end

  describe "#group_by_date_only?" do
    it "detects groupby - true" do
      report_options = described_class.new_from_h(:groupby => "date-only")
      expect(report_options.group_by_date_only?).to eq(true)
    end

    it "detects groupby - false" do
      report_options = described_class.new_from_h(:groupby => "date")
      expect(report_options.group_by_date_only?).to eq(false)
    end
  end

  describe "#group_by_date_first?" do
    it "detects groupby - true" do
      report_options = described_class.new_from_h(:groupby => "date-first")
      expect(report_options.group_by_date_first?).to eq(true)
    end

    it "detects groupby - false" do
      report_options = described_class.new_from_h(:groupby => "date")
      expect(report_options.group_by_date_only?).to eq(false)
    end
  end
end
