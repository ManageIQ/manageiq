describe ReportFormatter::C3Formatter do
  include Spec::Support::ReportHelper

  before(:each) do
    allow(Charting).to receive(:backend).and_return(:c3)
    allow(Charting).to receive(:format).and_return(:c3)
  end

  describe "#add_series" do
    it "does not raise error for 'stack' chart" do
      report = numeric_chart_3d(true)
      expect { render_report(report) }.to_not raise_error
    end
  end

  context '#build_numeric_chart_grouped' do
    [true, false].each do |other|
      it "builds 2d numeric charts from summaries #{other ? 'with' : 'without'} 'other'" do
        report = numeric_charts_2d_from_summaries(other)

        expect_any_instance_of(described_class).to receive(:build_numeric_chart_grouped).once.and_call_original
        render_report(report)
        expect(report.chart[:data][:columns][0][1]).to eq(4.0)
        expect(report.chart[:data][:columns][0][-1]).to eq(4) if other
      end
    end
  end

  context '#build_numeric_chart_simple' do
    let(:report) { numeric_chart_simple }
    let(:long_report) { numeric_chart_simple_with_long_strings }

    it "report chart have right data in ascending order" do
      report.col_formats = [nil, :general_number_precision_0]
      render_report(report)
      expect(report.chart[:data][:columns][0].count).to eq(report.table.data.count + 1)
      expect(report.chart[:data][:columns][0][1]).to eq(2024)
    end

    it "handles null data in chart column" do
      report = null_data_chart

      expect_any_instance_of(described_class).to receive(:build_numeric_chart_simple).once.and_call_original
      render_report(report)
    end

    it "handle long strings" do
      render_report(long_report)
      expect(long_report.chart[:miq][:category_table][2]).to eq(long_category)
      expect(long_report.chart[:miq][:name_table]['1']).to eq('RAM Size (MB)')
    end
  end

  context '#build_numeric_chart_simple' do
    [true, false].each do |other|
      it "builds 2d numeric charts #{other ? 'with' : 'without'} 'other'" do
        report = numeric_chart_simple2(other)

        expect_any_instance_of(described_class).to receive(:build_numeric_chart_simple).once.and_call_original
        render_report(report)
        expect(report.chart[:data][:columns][0][1]).to eq(15)
        expect(report.chart[:data][:columns][0][-1]).to eq(1) if other
      end
    end

    it "handles null data in chart column" do
      report = null_data_chart

      expect_any_instance_of(described_class).to receive(:build_numeric_chart_simple).once.and_call_original
      render_report(report)
    end
  end

  context '#build_numeric_chart_grouped_2dim' do
    [true, false].each do |other|
      it "builds 3d numeric charts #{other ? 'with' : 'without'} 'other'" do
        report = numeric_chart_3d(other)

        expect_any_instance_of(described_class).to receive(:build_numeric_chart_grouped_2dim).once.and_call_original
        render_report(report)
        expect(report.chart[:data][:columns][0][1]).to eq(6_656)
        expect(report.chart[:data][:columns][0][2]).to eq(4_096)
        expect(report.chart[:data][:columns][1][1]).to eq(1_024)
        expect(report.chart[:data][:columns][0][-1]).to eq(1_024) if other
      end
    end

    it 'handles namespace-prefixed class names in chart column' do
      report = chart_with_namespace_prefix

      expect_any_instance_of(described_class).to receive(:build_numeric_chart_grouped_2dim).once.and_call_original
      render_report(report)
    end
  end
end
