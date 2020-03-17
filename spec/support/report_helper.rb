module Spec
  module Support
    module ReportHelper
      def render_report(report)
        ManageIQ::Reporting::Formatter::ReportRenderer.render(ManageIQ::Reporting::Charting.format) do |e|
          e.options.mri           = report
          e.options.show_title    = true
          e.options.graph_options = MiqReport.graph_options
          e.options.theme         = 'miq'
          yield e if block_given?
        end
      end

      def numeric_charts_2d_from_summaries(other)
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
          :col_options => {"num_cpu" => {:grouping => %i(avg max min total)},
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
        report
      end

      def numeric_chart_simple
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

      def null_data_chart_with_basic_condition
        exp = YAML.load('--- !ruby/object:MiqExpression
        exp:
          INCLUDES:
            field: Name
            value: Amazon
        ')
        null_data_chart.tap { |r| r.update(:conditions => exp) }
      end

      def null_data_chart_with_complex_condition
        exp = YAML.load('--- !ruby/object:MiqExpression
        exp:
          and:
          - IS:
              field: VmPerformance-timestamp
              value: Last Hour
          - ">":
              value: "0"
              field: VmPerformance-cpu_usage_rate_average
          - INCLUDES:
              field: VmPerformance.vm-type
              value: Amazon
        ')
        null_data_chart.tap { |r| r.update(:conditions => exp) }
      end

      def numeric_chart_simple_with_long_strings
        report = MiqReport.new(
          :db          => "Host",
          :cols        => %w(name ram_size),
          :col_order   => %w(name ram_size),
          :headers     => [long_header, "RAM Size (MB)"],
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
            [long_category, 512, 1],
            ['ladas', 1024, 2],
            ['joker', 2024, 3],
          ]
        )
        report
      end

      def null_data_chart
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
        report
      end

      def numeric_chart_simple2(other)
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
            ["bar", 15, 1352],
            ["foo", 14,               1353],
            ["foo", 3,                1354],
            ["foo", 2,                1355],
            ["foo", 1,                1356],
            ["foo", 0,                1357],
          ],
        )
        report
      end

      def numeric_chart_3d(other)
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
            ["windows",      1_024, "MTC-RHEVM-3.0", 68],
            ["linux_centos", 4_096, "openstack",     70],
            ["windows",      2_048, "openstack",     69],
            ["windows",      1_024, "openstack",     71],
            ["linux_centos", 1_024, "ec2",           72],
            ["",             0,     "",              79],
          ],
        )
        report
      end

      def chart_with_namespace_prefix
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
        report
      end

      def cu_chart_without_grouping
        report = MiqReport.new(
          :db        => "VimPerformanceDaily",
          :cols      => %w(timestamp cpu_usagemhz_rate_average max_derived_cpu_available),
          :include   => {"resource" => {"columns" => %w(cpu_usagemhz_rate_average_high_over_time_period cpu_usagemhz_rate_average_low_over_time_period)}},
          :col_order => %w(timestamp cpu_usagemhz_rate_average max_derived_cpu_available),
          :headers   => ["Date/Time", "Avg Used", "Max Available"],
          :order     => "Ascending",
          :sortby    => %w(timestamp),
          :group     => "n",
          :graph     => {:type => "Line", :columns => %w(cpu_usagemhz_rate_average max_derived_cpu_available)},
          :extras    => {:trend => {"trend_max_cpu_usagemhz_rate_average|max_derived_cpu_available"=>"Trending Down"}}
        )

        report.table = Ruport::Data::Table.new(
          :column_names => %w(timestamp cpu_usagemhz_rate_average max_derived_cpu_available),
          :data         => [
            [Time.zone.local(2017, 8, 19, 0, 0, 0), 19_986.0, 41_584.0],
            [Time.zone.local(2017, 8, 20, 0, 0, 0), 205_632.0, 41_584.0]
          ]
        )
        report
      end

      def cu_chart_with_grouping
        report = MiqReport.new(
          :db          => "VimPerformanceDaily",
          :cols        => %w(timestamp cpu_usagemhz_rate_average__none_ max_derived_cpu_available_xa),
          :include     => {"resource" => {"columns" => %w(cpu_usagemhz_rate_average_high_over_time_period cpu_usagemhz_rate_average_low_over_time_period)}},
          :col_order   => %w(timestamp cpu_usagemhz_rate_average__none_ max_derived_cpu_available_xa),
          :headers     => ["Date/Time", "Avg Used", "Max Available"],
          :order       => "Ascending",
          :sortby      => %w(timestamp),
          :group       => "n",
          :graph       => {:type => "Line", :columns => %w(cpu_usagemhz_rate_average__none_ max_derived_cpu_available_xa)},
          :extras      => {:trend => {"trend_max_cpu_usagemhz_rate_average|max_derived_cpu_available"=>"Trending Down"}},
          :performance => {:group_by_category=>"environment"}
        )

        report.table = Ruport::Data::Table.new(
          :column_names => %w(timestamp cpu_usagemhz_rate_average__none_ max_derived_cpu_available_xa),
          :data         => [
            [Time.zone.local(2017, 8, 19, 0, 0, 0), 19_986.0, 41_584.0],
            [Time.zone.local(2017, 8, 20, 0, 0, 0), 205_632.0, 41_584.0]
          ]
        )
        report
      end

      def cu_chart_with_no_data
        report = MiqReport.new(
          :db        => "VimPerformanceDaily",
          :cols      => %w(timestamp cpu_usagemhz_rate_average max_derived_cpu_available),
          :include   => {"resource" => {"columns" => %w(cpu_usagemhz_rate_average_high_over_time_period cpu_usagemhz_rate_average_low_over_time_period)}},
          :col_order => %w(timestamp cpu_usagemhz_rate_average max_derived_cpu_available),
          :headers   => ["Date/Time", "Avg Used", "Max Available"],
          :order     => "Ascending",
          :sortby    => %w(timestamp),
          :group     => "n",
          :graph     => {:type => "Line", :columns => %w(cpu_usagemhz_rate_average max_derived_cpu_available)},
          :extras    => {:trend => {"trend_max_cpu_usagemhz_rate_average|max_derived_cpu_available"=>"Trending Down"}}
        )

        report.table = Ruport::Data::Table.new(
          :column_names => %w(timestamp cpu_usagemhz_rate_average max_derived_cpu_available),
          :data         => []
        )
        report
      end

      def long_category
        'Daenerys Targaryen, the First of Her Name, Queen of Meereen, Queen of the Andals and the Rhoynar and the First Men,\
         Lord of the Seven Kingdoms, Protector of the Realm, Khaleesi of the Great Grass Sea, called Daenerys Stormborn, the Unburnt,\
          Mother of Dragons.'
      end

      def long_header
        "Here is header loooooong as hell"
      end
    end
  end
end
