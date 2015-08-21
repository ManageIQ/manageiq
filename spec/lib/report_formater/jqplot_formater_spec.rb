require 'spec_helper'

describe ReportFormatter::JqplotFormatter do
  context '#build_numeric_chart_grouped' do
    [true, false].each do |other|
      it "builds 2d numeric charts from summaries #{other ? 'with' : 'without'} 'other'" do
        report = MiqReport.new(
          :db          => "Vm",
          :sortby      => ["ext_management_system.name"],
          :order       => "Descending",
          :cols        => %w(name num_cpu),
          :include     => {"ext_management_system" => {"columns" => ["name"]}},
          :col_order   => %w(name num_cpu ext_management_system.name),
          :headers     => ["Name", "Number of CPUs", "Cloud/Infrastructure Provider Name"],
          :dims        => 1,
          :group       => "y",
          :rpt_options => {:summary => {:hide_detail_rows => false}},
          :col_options => {"num_cpu" => {:grouping => [:avg, :max, :min, :total]},
                           "name"    => {:break_label => "Cloud/Infrastructure Provider : Name: "}},
          :graph       => {:type => "Column", :mode => "values", :column => "Vm-num_cpu:total", :count => 2, :other => other},
          :extras      => {},
        )

        report.table = Ruport::Data::Table.new(
          :column_names => %w(name num_cpu ext_management_system.name id),
          :data         => [
            ["bar", 1, system_name_1 = 'blah', 352],
            ["foo", 3, system_name_1,          353],
            ["pat", 1, system_name_2 = 'bleh', 354],
            ["mat", 1, system_name_2,          355],
            ["cuk", 1, system_name_3 = 'blrg', 356],
            ["gek", 2, system_name_3,          357],
            ["tik", 1, system_name_4 = 'blud', 358],
            ["tak", 1, system_name_4,          359],
          ],
        )

        expect_any_instance_of(described_class).to receive(:build_numeric_chart_grouped).once.and_call_original

        ReportFormatter::ReportRenderer.render(Charting.format) do |e|
          e.options.mri           = report
          e.options.show_title    = true
          e.options.graph_options = MiqReport.graph_options(600, 400)
          e.options.theme         = 'miq'
        end

        expect(report.chart[:data][0][0]).to eq(4.0)
        expect(report.chart[:options][:axes][:xaxis][:ticks][0]).to eq(system_name_1)
        expect(report.chart[:data][0][-1]).to eq(4) if other
      end
    end
  end

  context '#build_numeric_chart_simple' do
    [true, false].each do |other|
      it "builds 2d numeric charts #{other ? 'with' : 'without'} 'other'" do
        report = MiqReport.new(
          :db          => "Host",
          :sortby      => %w(name),
          :order       => "Descending",
          :cols        => %w(name v_total_vms),
          :include     => {},
          :col_order   => %w(name v_total_vms),
          :headers     => ["Name", "Total VMs"],
          :dims        => 1,
          :group       => nil,
          :rpt_options => {},
          :col_options => {},
          :graph       => {:type => "Bar", :mode => "values", :column => "Host-v_total_vms", :count => 4, :other => other},
          :extras      => {},
        )

        report.table = Ruport::Data::Table.new(
          :column_names => %w(name v_total_vms id),
          :data         => [
            [host_name_1 = "bar", 15, 1352],
            ["foo", 14,               1353],
            ["foo", 3,                1354],
            ["foo", 2,                1355],
            ["foo", 1,                1356],
            ["foo", 0,                1357],
          ],
        )

        expect_any_instance_of(described_class).to receive(:build_numeric_chart_simple).once.and_call_original

        ReportFormatter::ReportRenderer.render(Charting.format) do |e|
          e.options.mri           = report
          e.options.show_title    = true
          e.options.graph_options = MiqReport.graph_options(600, 400)
          e.options.theme         = 'miq'
        end

        expect(report.chart[:data][0][0]).to eq(15)
        expect(report.chart[:options][:axes][:yaxis][:ticks][0]).to eq(host_name_1)
        expect(report.chart[:data][0][-1]).to eq(1) if other
      end
    end
  end
end
