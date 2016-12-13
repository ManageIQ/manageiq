describe ReportFormatter::JqplotFormatter do
  include Spec::Support::ReportHelper

  before(:each) do
    allow(Charting).to receive(:backend).and_return(:jqplot)
    allow(Charting).to receive(:format).and_return(:jqplot)
  end
  context '#build_reporting_chart_dim2' do
    it 'builds a stacked chart' do
      report = MiqReport.new(
        :db          => "Vm",
        :cols        => %w(os_image_name),
        :include     => {"ext_management_system" => {"columns" => ["name"]}},
        :col_order   => ["ext_management_system.name", "os_image_name"],
        :headers     => ["Cloud/Infrastructure Provider Name", "OS Name"],
        :order       => "Ascending",
        :group       => nil,
        :graph       => {:type => "StackedBar", :mode => "counts", :column => nil, :count => 10, :other => false},
        :dims        => 2,
        :col_options => {},
        :rpt_options => {},
        :sortby      => %w(ext_management_system.name os_image_name)
      )

      report.table = Ruport::Data::Table.new(
        :column_names => %w(os_image_name ext_management_system.name id),
        :data         => [
          %w(linux_centos MTC-RHEVM-3.0 10000000000012),
          %w(linux_centos MTC-RHEVM-3.0 10000000000013),
          %w(linux_redhat MTC-RHEVM-3.1 10000000000014),
          %w(linux_centos MTC-RHEVM-3.1 10000000000015),
        ]
      )

      expect_any_instance_of(described_class).to receive(:build_reporting_chart_dim2).once.and_call_original
      render_report(report)
      expect(report.chart[:data]).to eq([[2, 1], [0, 1]])
      expect(report.chart[:options][:seriesDefaults][:renderer]).to eq("jQuery.jqplot.BarRenderer")
      expect(report.chart[:options][:series]).to eq([{:label => "linux_centos"}, {:label => "linux_redhat"}])
    end
  end

  context "#build_reporting_chart_other" do
    it 'builds a pie chart' do
      report = MiqReport.new(
        :db          => "Host",
        :cols        => %w(os_image_name),
        :include     => {},
        :col_order   => ["os_image_name"],
        :headers     => ["OS Name"],
        :order       => "Ascending",
        :sortby      => ["os_image_name"],
        :group       => nil,
        :graph       => {:type => "Pie", :mode => "counts", :column => nil, :count => 10, :other => true},
        :dims        => 1,
        :col_options => {},
        :rpt_options => {},
      )

      report.table = Ruport::Data::Table.new(
        :column_names => %w(os_image_name id),
        :data         => [
          ["linux_esx", 5],
          ["linux_esx", 6],
          ["linux_esx", 7],
          ["widloze",   8],
        ]
      )

      expect_any_instance_of(described_class).to receive(:build_reporting_chart_other).once.and_call_original
      render_report(report)
      expect(report.chart[:data][0]).to eq([["linux_esx: 3", 3], ["widloze: 1", 1]])
      expect(report.chart[:options][:seriesDefaults][:renderer]).to eq("jQuery.jqplot.PieRenderer")
      expect(report.chart[:options][:highlighter]).to be_truthy
    end
  end
end
