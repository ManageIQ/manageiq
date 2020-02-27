describe ManageIQ::Reporting::Formatter::C3 do
  include Spec::Support::ReportHelper

  before do
    allow(ManageIQ::Reporting::Charting).to receive(:backend).and_return(:c3)
    allow(ManageIQ::Reporting::Charting).to receive(:format).and_return(:c3)
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
        labels = ["MTC-RHEVM-3.0", "openstack"]
        labels.push("Other") if other
        expect(report.chart[:axis][:x][:categories]).to eq(labels)
        expect(report.chart[:miq][:category_table]).to eq(labels)
      end
    end

    it 'handles namespace-prefixed class names in chart column' do
      report = chart_with_namespace_prefix

      expect_any_instance_of(described_class).to receive(:build_numeric_chart_grouped_2dim).once.and_call_original
      render_report(report)
    end
  end

  context '#C&U charts without grouping' do
    let(:report) { cu_chart_without_grouping }
    before do
      render_report(report, &proc { |e| e.options.graph_options = { :chart_type => :performance } })
    end

    it "has right data" do
      expect(report.chart[:data][:columns][0].count).to eq(report.table.data.count + 1)
      expect(report.chart[:data][:columns][0]).to eq(["x", "8/19", "8/20"])
      expect(report.chart[:data][:columns][1]).to eq(["1", 19_986.0, 205_632.0])
      expect(report.chart[:data][:columns][2]).to eq(["2", 41_584.0, 41_584.0])
    end

    it "has right type" do
      expect(report.chart[:axis][:x][:type]).to eq("timeseries")
    end

    it 'has right formatting functions' do
      expect(report.chart[:axis][:y][:tick][:format][:function]).to eq("mhz_to_human_size")
      expect(report.chart[:miq][:format][:function]).to eq("mhz_to_human_size")
    end
    it 'has right tabels' do
      expect(report.chart[:miq][:name_table]).to eq("1" => "Avg Used", "2" => "Max Available")
      expect(report.chart[:miq][:category_table]).to eq(["8/19", "8/20"])
    end
  end

  context '#C&U charts with grouping' do
    let(:report) { cu_chart_with_grouping }
    before do
      render_report(report, &proc { |e| e.options.graph_options = { :chart_type => :performance } })
    end

    it "has right data" do
      expect(report.chart[:data][:columns][0].count).to eq(report.table.data.count + 1)
      expect(report.chart[:data][:columns][0]).to eq(["x", "8/19", "8/20"])
      expect(report.chart[:data][:columns][1]).to eq(["1", 19_986.0, 205_632.0])
      expect(report.chart[:data][:columns][2]).to eq(["2", 41_584.0, 41_584.0])
    end

    it "has right type" do
      expect(report.chart[:axis][:x][:type]).to eq("timeseries")
    end

    it 'has right formatting functions' do
      expect(report.chart[:axis][:y][:tick][:format][:function]).to eq("mhz_to_human_size")
      expect(report.chart[:miq][:format][:function]).to eq("mhz_to_human_size")
    end
    it 'has right tabels' do
      expect(report.chart[:miq][:name_table]).to eq("1" => "Avg Used", "2" => "Max Available")
      expect(report.chart[:miq][:category_table]).to eq(["8/19", "8/20"])
    end
  end

  context '#C&U charts with no data' do
    let(:report) { cu_chart_with_grouping }
    before do
      render_report(report, &proc { |e| e.options.graph_options = { :chart_type => :performance } })
    end

    it "has right empty data description" do
      expect(report.chart[:data][:empty][:label][:text]).to eq("No data available.")
    end
  end
end
