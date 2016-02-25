include ReportsSpecHelper

describe ReportFormatter::JqplotFormatter do
  before(:each) do
    allow(Charting).to receive(:backend).and_return(:jqplot)
    allow(Charting).to receive(:format).and_return(:jqplot)
  end
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
        render_report(report)
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
        render_report(report)
        expect(report.chart[:data][0][0]).to eq(15)
        expect(report.chart[:options][:axes][:yaxis][:ticks][0]).to eq(host_name_1)
        expect(report.chart[:data][0][-1]).to eq(1) if other
      end
    end

    it "handles null data in chart column" do
      report = MiqReport.new(
        :db          => "Vm",
        :cols        => %w(name),
        :include     => {"hardware" => {"columns" => %w(cpu_speed cpu_sockets memory_mb)}},
        :col_order   => %w(name hardware.cpu_speed hardware.cpu_sockets hardware.memory_mb),
        :headers     => ["Name", "Hardware CPU Speed", "Hardware Number of CPUs", "Hardware RAM"],
        :order       => "Ascending",
        :sortby      => %w(name),
        :graph       => {:type => "Bar", :mode => "values", :column => "Vm.hardware-cpu_sockets", :count => 10, :other => true},
        :dims        => 1,
        :col_options => {},
        :rpt_options => {},
        :extras      => {},
      )

      report.table = Ruport::Data::Table.new(
        :column_names => %w(name hardware.cpu_speed hardware.cpu_sockets hardware.memory_mb id),
        :data         => [
          ["Чук", nil, 4,   6_144, 42],
          ["Гек", nil, nil, 1_024, 49],
        ],
      )

      expect_any_instance_of(described_class).to receive(:build_numeric_chart_simple).once.and_call_original
      render_report(report)
    end
  end

  context '#build_numeric_chart_grouped_2dim' do
    [true, false].each do |other|
      it "builds 3d numeric charts #{other ? 'with' : 'without'} 'other'" do
        report = MiqReport.new(
          :db          => "Vm",
          :cols        => %w(os_image_name mem_cpu),
          :include     => {"ext_management_system" => {"columns" => ["name"]}},
          :col_order   => %w(ext_management_system.name os_image_name mem_cpu),
          :headers     => ["Cloud/Infrastructure Provider Name", "OS Name", "Memory"],
          :order       => "Ascending",
          :sortby      => %w(ext_management_system.name os_image_name),
          :group       => "y",
          :graph       => {:type => "StackedBar", :mode => "values", :column => "Vm-mem_cpu:total", :count => 2, :other => other},
          :dims        => 2,
          :col_options => {"name" => {:break_label => "Cloud/Infrastructure Provider : Name: "}, "mem_cpu" => {:grouping => [:total]}},
          :rpt_options => {:summary => {:hide_detail_rows => false}},
          :extras      => {},
        )

        report.table = Ruport::Data::Table.new(
          :column_names => %w(os_image_name mem_cpu ext_management_system.name id),
          :data         => [
            ["linux_centos", 6_144, "MTC-RHEVM-3.0", 67],
            ["linux_centos", 512,   "MTC-RHEVM-3.0", 167],
            ["widloze",      1_024, "MTC-RHEVM-3.0", 68],
            ["linux_centos", 4_096, "openslack",     70],
            ["widloze",      2_048, "openslack",     69],
            ["widloze",      1_024, "openslack",     71],
            ["linux_centos", 1_024, "ec2",           72],
            ["",             0,     "",              79],
          ],
        )

        expect_any_instance_of(described_class).to receive(:build_numeric_chart_grouped_2dim).once.and_call_original
        render_report(report)
        expect(report.chart[:data][0][0]).to eq(6_656)
        expect(report.chart[:data][0][1]).to eq(4_096)
        expect(report.chart[:data][1][1]).to eq(3_072)
        expect(report.chart[:options][:axes][:yaxis][:ticks][0]).to eq('MTC-RHEVM-3.0')
        expect(report.chart[:data][0][-1]).to eq(1_024) if other
      end
    end

    it 'handles namespace-prefixed class names in chart column' do
      report = MiqReport.new(
        :db          => "ManageIQ::Providers::InfraManager::Vm",
        :cols        => %w(os_image_name cpu_total_cores num_cpu),
        :include     => {"host" => {"columns" => %w(name)}},
        :col_order   => %w(os_image_name host.name cpu_total_cores num_cpu),
        :headers     => ["OS Name", "Host / Node Name", "Number of CPU Cores", "Number of CPUs"],
        :order       => "Ascending",
        :sortby      => %w(host.name os_image_name),
        :group       => "y",
        :graph       => {:type => "Bar", :mode => "values", :column => "ManageIQ::Providers::InfraManager::Vm-num_cpu:total", :count => 10, :other => true},
        :dims        => 2,
        :col_options => {"name" => {:break_label => "Host / Node : Name: "}, "num_cpu" => {:grouping => [:total]}},
        :rpt_options => {:summary => {:hide_detail_rows => false}},
        :extras      => {}
      )

      report.table = Ruport::Data::Table.new(
        :column_names => %w(os_image_name cpu_total_cores num_cpu host.name id),
        :data         => [
          ["linux_centos", 8, 2, "MTC-RHEVM-3.0", 67],
        ]
      )

      expect_any_instance_of(described_class).to receive(:build_numeric_chart_grouped_2dim).once.and_call_original
      render_report(report)
    end
  end

  context '#build_numeric_chart_simple' do
    let(:report) do
      report = MiqReport.new(
        :db          => "Host",
        :cols        => %w(name ram_size),
        :col_order   => %w(name ram_size),
        :headers     => ["Name", "RAM Size (MB)"],
        :order       => "Ascending",
        :sortby      => %w(name),
        :group       => nil,
        :graph       => {:type => "Bar", :mode => "values", :column => "Host-ram_size", :count => 10, :other => false},
        :dims        => 1,
        :col_options => {},
        :extras      => {},
      )

      report.table = Ruport::Data::Table.new(
        :column_names => %w(name ram_size id),
        :data         => [
          ['jenda',  512, 1],
          ['ladas', 1024, 2],
          ['joker', 2024, 3],
        ]
      )

      report
    end

    it "uses correct formating function for axis with given column format" do
      report.col_formats = [nil, :general_number_precision_0]
      render_report(report)
      expect(report.chart[:options][:axes][:xaxis][:tickOptions][:formatter]).to eq("ManageIQ.charts.formatters.number_with_delimiter.jqplot({})")
    end

    it "uses correct formating function for axis with implicit column format" do
      render_report(report)
      expect(report.chart[:options][:axes][:xaxis][:tickOptions][:formatter]).to eq("ManageIQ.charts.formatters.mbytes_to_human_size.jqplot({})")
    end
  end
end
