describe ManageIQ::Reporting::Formatter::Text do
  include Spec::Support::ReportHelper

  before do
    allow(ManageIQ::Reporting::Charting).to receive(:backend).and_return(:text)
    allow(ManageIQ::Reporting::Charting).to receive(:format).and_return(:text)
  end

  it "expands report width for really long filter condition" do
    report = null_data_chart_with_complex_condition
    Timecop.freeze do
      result = render_report(report) { |r| r.options.ignore_table_width = true }

      expected = <<~TABLE
        +--------------------------------------------------------------------+
        | Name | Hardware CPU Speed | Hardware Number of CPUs | Hardware RAM |
        +--------------------------------------------------------------------+
        | Чук  |                    | 4                       | 6 GB         |
        | Гек  |                    |                         | 1 GB         |
        +--------------------------------------------------------------------+
        +--------------------------------------------------------------------+
        |Report based filter fields:                                         |
        |( Performance - VM : Activity Sample - Timestamp (Day/Time) IS "Last Hour" AND Performance - VM : CPU - Usage Rate for Collected Intervals (%) > 0 AND Performance - VM.VM and Instance : Type INCLUDES "Amazon" )|
        +--------------------------------------------------------------------+
        |                  #{described_class.format_timezone(Time.zone.now)}                   |
        +--------------------------------------------------------------------+
        TABLE
      result.lines.each_with_index do |line, index|
        expect(line.strip).to eq(expected.lines[index].strip)
      end
    end
  end

  it "renders basic text report" do
    report = null_data_chart
    Timecop.freeze do
      result = render_report(report)
      expected = <<~TABLE
        +--------------------------------------------------------------------+
        | Name | Hardware CPU Speed | Hardware Number of CPUs | Hardware RAM |
        +--------------------------------------------------------------------+
        | Чук  |                    | 4                       | 6 GB         |
        | Гек  |                    |                         | 1 GB         |
        +--------------------------------------------------------------------+
        +--------------------------------------------------------------------+
        |                  #{described_class.format_timezone(Time.zone.now)}                   |
        +--------------------------------------------------------------------+
        TABLE
      result.lines.each_with_index do |line, index|
        expect(line.strip).to eq(expected.lines[index].strip)
      end
    end
  end

  it "renders report with basic filter condition" do
    report = null_data_chart_with_basic_condition
    Timecop.freeze do
      result = render_report(report)
      expected = <<~TABLE
        +--------------------------------------------------------------------+
        | Name | Hardware CPU Speed | Hardware Number of CPUs | Hardware RAM |
        +--------------------------------------------------------------------+
        | Чук  |                    | 4                       | 6 GB         |
        | Гек  |                    |                         | 1 GB         |
        +--------------------------------------------------------------------+
        +--------------------------------------------------------------------+
        |Report based filter fields:                                         |
        | Name INCLUDES "Amazon"                                             |
        +--------------------------------------------------------------------+
        |                  #{described_class.format_timezone(Time.zone.now)}                   |
        +--------------------------------------------------------------------+
        TABLE
      result.lines.each_with_index do |line, index|
        expect(line.strip).to eq(expected.lines[index].strip)
      end
    end
  end
end
