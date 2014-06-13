require File.expand_path(File.join(File.dirname(__FILE__), '..', 'test_helper'))

class VimPerformancePlanningTest < ActiveSupport::TestCase
  $db_name = "vmdb_cu_analytics"
  $skip_test = true

  ActiveRecord::Base.establish_connection(
    :adapter  => "postgresql",
    :host     => "localhost",
    :username => "root",
    :password => "smartvm",
    :database => $db_name
  ) unless $skip_test

  $base_options = {
    :range        => {
      :days         => 20,
      :end_date     => Time.now.utc
    },
    :vm_options => {
      :cpu    => {
        :mode   => :perf_trend,
        :metric => :max_cpu_usagemhz_rate_average
      },
      :memory => {
        :mode   => :perf_trend,
        :metric => :max_derived_memory_used
      },
      :storage => {
        :mode   => :current,
        :metric => :used_disk_storage
      }
    },
    :target_options => {
      :cpu     => {
        :mode       => :perf_trend,
        :metric     => :max_cpu_usagemhz_rate_average,
        :limit_col  => :derived_cpu_available,
        :limit_pct  => 90
      },
      :memory  => {
        :mode       => :perf_trend,
        :metric     => :max_derived_memory_used,
        :limit_col  => :derived_memory_available,
        :limit_pct  => 90
      },
      :storage => {
        :mode       => :current,
        :metric     => :used_space,
        :limit_col  => :total_space,
        :limit_pct  => 80
      }
    }
  }

  test "instantiate with explicit targets" do
    return if $skip_test
    # Test explicit targets:
    #
    # Cluster
    #
    assert_nothing_raised {
      cluster = EmsCluster.find(:first)
      targets = {
        :compute      => cluster,
        :storage      => cluster.hosts.collect {|h| h.storages}.flatten.compact.first
      }
      options = $base_options.merge(:targets => targets)
      vm = cluster.all_vms.first
      p = VimPerformanceAnalysis::Planning.new(vm, options)
      puts "Explicit targets:"
      puts "Compute: #{p.compute.inspect}"
      puts "Storage: #{p.storage.inspect}"
    }
    #
    # Host
    #
    assert_nothing_raised {
      host = Host.find_by_name("titan.galaxy.local")
      targets = {
        :compute      => host,
        :storage      => host.storages.first
      }
      vm = host.vms.first
      options = $base_options.merge(:targets => targets)
      p = VimPerformanceAnalysis::Planning.new(vm, options)
      puts "Explicit targets:"
      puts "Compute: #{p.compute.inspect}"
      puts "Storage: #{p.storage.inspect}"
    }
    #
  end

  test "instantiate with implicit tag targets" do
    return if $skip_test
    # Test target_tags
    #
    assert_nothing_raised {
      target_tags = {
        :compute_type => :Host,
        :compute_tags => [["/managed/environment/prod"]],
        :storage_tags => [["/managed/environment/prod"]]
      }
      vm = Vm.find(17)
      options = $base_options.merge(:target_tags => target_tags)
      p = VimPerformanceAnalysis::Planning.new(vm, options)
      puts "Implicit, tag, targets:"
      puts "Compute: #{p.compute.inspect}"
      puts "Storage: #{p.storage.inspect}"
    }
    #
  end

  test "report generation" do
    return if $skip_test
    assert_nothing_raised {
      target_tags = {
        :compute_type => :Host,
        :compute_tags => [["/managed/environment/prod"]],
        :storage_tags => [["/managed/environment/prod"]]
      }
      vm = Vm.find(19)
      options = $base_options.merge(:vm => vm, :target_tags => target_tags)

      rpt = MiqReport.new()
      rpt.db = "VimPerformancePlanning"
      rpt.cols = VimPerformancePlanning.column_names
      rpt.col_order = VimPerformancePlanning.column_names
      rpt.db_options = {:rpt_type => "planning", :options => options}
      rpt.generate_table
      puts "Report Generation:"
      puts "Table: #{rpt.table.inspect}"
    }
  end

  test "report generation with targets and ids" do
    return if $skip_test
    assert_nothing_raised {
      targets = {
        :host => 7,
        :storage => 15,
      }
      vm = 19
      options = $base_options.merge(:vm => vm, :targets => targets)

      rpt = MiqReport.new()
      rpt.db = "VimPerformancePlanning"
      rpt.cols = VimPerformancePlanning.column_names
      rpt.col_order = VimPerformancePlanning.column_names
      rpt.db_options = {:rpt_type => "planning", :options => options}
      rpt.generate_table
      puts "Report Generation with targets and ids:"
      puts "Table: #{rpt.table.inspect}"
    }

    assert_nothing_raised {
      targets = {
        :cluster => EmsCluster.all.collect {|c| c.id},
        :storage => Storage.all.collect {|s| s.id}
      }
      vm = 19
      options = $base_options.merge(:vm => vm, :targets => targets)

      rpt = MiqReport.new()
      rpt.db = "VimPerformancePlanning"
      rpt.cols = VimPerformancePlanning.column_names
      rpt.col_order = VimPerformancePlanning.column_names
      rpt.db_options = {:rpt_type => "planning", :options => options}
      rpt.generate_table
      puts "Report Generation with targets and ids:"
      puts "Table: #{rpt.table.inspect}"
    }
  end

  test "vm_how_many_more_can_fit method" do
    return if $skip_test
    hosts      = Host.find(:all)
    storages   = Storage.find(:all)

    # VM Ids: 17, 19 ,21 ,15 ,16 all have values for used_disk_storage
    vm         = Vm.find_by_id(17)

    targets = {
      :compute      => hosts,
      :storage      => storages
    }

    options = $base_options.merge(:targets => targets)
    p = VimPerformanceAnalysis::Planning.new(vm, options)

    result, vm_needs = p.vm_how_many_more_can_fit(options)

    assert result, kind_of?(Array)

    result.each { |h|
      target = h[:target]
      counts = h[:count]

      puts "#{target.class.to_s} #{target.name} fits: #{counts.inspect}"
    }

  end

  test "vm_how_many_more_can_fit method formatted results" do
    return if $skip_test
    hosts      = Host.find(:all)
    storages   = Storage.find(:all)

    # VM Ids: 17, 19 ,21 ,15 ,16 all have values for used_disk_storage
    vm         = Vm.find_by_id(17)

    targets = {
      :compute      => hosts,
      :storage      => storages
    }

    options = $base_options.merge(:targets => targets)
    p = VimPerformanceAnalysis::Planning.new(vm, options)

    # result, needs = p.vm_how_many_more_can_fit(options)
    result, needs = p.vm_how_many_more_can_fit(options)
    assert result, kind_of?(Array)

    puts "VM [#{vm.name}] Needs:"
    [:cpu, :memory, :storage].each {|t| puts "    #{t.to_s.titleize}: \t\t#{needs[t]}" if needs && needs[t] }; puts

    puts
    result.each { |h|
      target = h[:target]
      counts = h[:count]

      next if counts[:total][:total].blank?

      puts "#{target.class.to_s} [#{target.name}] fits: #{counts[:total][:total]}"
      [:cpu, :memory, :storage].each {|t| puts "    #{t.to_s.titleize}: \t\t#{counts[t][:total]}" if counts[t] }; puts
    }
  end
end
