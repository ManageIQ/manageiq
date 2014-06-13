$skip_test = true

unless $skip_test

  require File.expand_path(File.join(File.dirname(__FILE__), '..', 'test_helper'))
  require 'ap'

  class VimPerformancePlanningAnalysisTest < ActiveSupport::TestCase
    ########### TODO - Move data necessary for test into yaml fixtures to loaded into factories #############
    $db_name = "sp65_gt_perf_1"

    ActiveRecord::Base.establish_connection(
      :adapter  => "postgresql",
      :host     => "localhost",
      :username => "root",
      :password => "smartvm",
      :database => $db_name
    )
    ###########

    context "With a set of UI options, " do
      setup do
        @options = {
          :userid=>"admin",
          :target_options=>{
            :vcpus    =>{                                                                                                    :limit_ratio=>12},
            :storage  =>{:mode=>:current,     :limit_col=>:total_space,             :metric=>:used_space,                    :limit_pct  =>90},
            :cpu      =>{:mode=>:perf_trend,  :limit_col=>:derived_cpu_available,   :metric=>:max_cpu_usagemhz_rate_average, :limit_pct  =>90},
            :memory   =>{:mode=>:perf_trend,  :limit_col=>:derived_memory_available,:metric=>:max_derived_memory_used,       :limit_pct  =>90}
          },
          :target_tags=>{:compute_type=>:EmsCluster},
          :ext_options=>{:tz=>"UTC", :only_cols=>["name", "id", "resource_type", "total_vm_count", "cpu_vm_count", "vcpus_vm_count", "memory_vm_count", "storage_vm_count"], :time_profile=>nil},
          :vm_options =>{
            :vcpus    =>{:mode=>:current,     :metric=>:num_cpu},
            :storage  =>{:mode=>:current,     :metric=>:used_disk_storage},
            :cpu      =>{:mode=>:perf_trend,  :metric=>:max_cpu_usagemhz_rate_average},
            :memory   =>{:mode=>:perf_trend,  :metric=>:max_derived_memory_used}
          },
          :range=>{:days=>28, :end_date=>"Tue, 06 Apr 2010 23:00:00 UTC +00:00".to_time.utc}
        }
      end

      context "manual values and no VM, " do
        setup do
          @options[:vm_options] = {
            :cpu     => {:value =>  5454.12,   :mode => :manual},
            :vcpus   => {:value =>  2,         :mode => :manual},
            :memory  => {:value =>  4096,      :mode => :manual},
            :storage => {:value =>  123456789, :mode => :manual}
          }
        end

        should "return the correct values from analysis vm_how_many_more_can_fit" do
          assert_nothing_raised {
            p = VimPerformanceAnalysis::Planning.new(nil, @options)
            @results, @vm_needs = p.vm_how_many_more_can_fit(@options)
          }

          assert_equal    2,          @vm_needs[:vcpus]
          assert_equal    4096,       @vm_needs[:memory]
          assert_in_delta 5454.12,    @vm_needs[:cpu],    0.00001
          assert_equal    123456789,  @vm_needs[:storage]

          @results.sort! {|a,b| (b[:count][:total][:total] || 0) <=> (a[:count][:total][:total] || 0)}
          counts = @results.first[:count]
          # assert_equal  3, counts[:total][:total]
          assert_equal  1, counts[:total][:total]
          # [[:vcpus, 7], [:cpu, 4], [:memory, 3], [:storage, 121438]].each  {|t|
          [[:vcpus, 44], [:cpu, 3], [:memory, 1], [:storage, 43078]].each  {|t|
            type, value = t
            assert_equal  value, counts[type][:total]
          }
        end

        should "return the values passed in options to planning vm_metric_values" do
          assert_nothing_raised {
            options = {:vm_options => @options[:vm_options]}
            @result = VimPerformancePlanning.vm_metric_values(nil, options)
          }

          assert_equal    2,          @result[:vm_options][:vcpus][:value]
          assert_equal    4096,       @result[:vm_options][:memory][:value]
          assert_equal    5454,       @result[:vm_options][:cpu][:value],    0.00001
          assert_equal    123456789,  @result[:vm_options][:storage][:value]
        end
      end

      context "a chosen VM, " do
        setup do
          @vm = Vm.find(175)
        end

        context "host target, " do
          setup do
            @options[:target_tags]={:compute_type=>:Host}
          end

          should "return the correct values analysis vm_how_many_more_can_fit" do
            assert_nothing_raised {
              p = VimPerformanceAnalysis::Planning.new(@vm, @options)
              @results, @vm_needs = p.vm_how_many_more_can_fit(@options)
            }

            assert_equal    2,                @vm_needs[:vcpus]
            assert_in_delta 3444.75107056682, @vm_needs[:memory], 0.00001
            assert_in_delta 433.391627680321, @vm_needs[:cpu],    0.00001
            assert_equal    17318281216,      @vm_needs[:storage]

            @results.sort! {|a,b| (b[:count][:total][:total] || 0) <=> (a[:count][:total][:total] || 0)}
            counts = @results.first[:count]
            assert_equal  1, counts[:total][:total]
            [[:vcpus, 4], [:cpu, 17], [:memory, 1], [:storage, 279]].each  {|t|
              type, value = t
              assert_equal  value, counts[type][:total]
            }

            # Test a host that have VM reserve values that affect the total count
            host_with_reserve = @results.select {|r| r[:target].name == "esx35dev001.localdomain"}.first
            counts = host_with_reserve[:count]
            assert_equal  0, counts[:total][:total]
            [[:cpu, 7], [:memory, 0]].each  {|t|
              type, value = t
              assert_equal  value, counts[type][:total]
            }

            # @results.each {|r|
            #   puts "Cluster: #{r[:target].ems_cluster ? r[:target].ems_cluster.name : "<none>"}, Target: #{r[:target].name}, #{r[:count].inspect}"
            # }
          end
        end

        context "cluster target, " do
          setup do
          end

          should "return the correct values from cluster analysis vm_how_many_more_can_fit" do
            assert_nothing_raised {
              p = VimPerformanceAnalysis::Planning.new(@vm, @options)
              @results, @vm_needs = p.vm_how_many_more_can_fit(@options)
            }

            assert_equal    2,                @vm_needs[:vcpus]
            assert_in_delta 3444.75107056682, @vm_needs[:memory], 0.00001
            assert_in_delta 433.391627680321, @vm_needs[:cpu],    0.00001
            assert_equal    17318281216,      @vm_needs[:storage]

            @results.sort! {|a,b| (b[:count][:total][:total] || 0) <=> (a[:count][:total][:total] || 0)}
            counts = @results.first[:count]
            # assert_equal  3, counts[:total][:total]
            assert_equal  2, counts[:total][:total]
            # [[:vcpus, 7], [:cpu, 57], [:memory, 3], [:storage, 842]].each  {|t|
            [[:vcpus, 44], [:cpu, 54], [:memory, 2], [:storage, 298]].each  {|t|
              type, value = t
              assert_equal  value, counts[type][:total]
            }
          end
        end

        should "return the correct VM profile from analysis" do
          assert_nothing_raised {
            p = VimPerformanceAnalysis::Planning.new(@vm, @options)
            @vm_needs = p.get_vm_needs
          }

          assert_equal    2,                @vm_needs[:vcpus]
          assert_in_delta 3444.75107056682, @vm_needs[:memory], 0.00001
          assert_in_delta 433.391627680321, @vm_needs[:cpu],    0.00001
          assert_equal    17318281216,      @vm_needs[:storage]
        end

        should "return the correct values from planning vm_metric_values" do
          assert_nothing_raised {
            options = {:vm_options => @options[:vm_options], :range => @options[:range]}
            @result = VimPerformancePlanning.vm_metric_values(@vm, options)
          }

          assert_equal    2,            @result[:vm_options][:vcpus][:value]
          assert_equal 3445,            @result[:vm_options][:memory][:value]
          assert_equal  433,            @result[:vm_options][:cpu][:value]
          assert_equal 17318281216,     @result[:vm_options][:storage][:value]
        end

        should "return the correct values from planning vm_metric_values when :mode == :allocated" do
          @vm_options = {
            :vcpus    =>{:metric => :num_cpu, :mode => :current},
            :storage  =>{:metric => :allocated_disk_storage, :mode => :current},
            :cpu      =>nil,
            :memory   =>{:metric => :ram_size, :mode => :current}
          }

          assert_nothing_raised {
            options = {:vm_options => @vm_options, :range => @options[:range]}
            @result = VimPerformancePlanning.vm_metric_values(@vm, options)
          }

          assert_equal    2,        @result[:vm_options][:vcpus][:value]
          assert_equal 4096,        @result[:vm_options][:memory][:value]
          assert_equal nil,         @result[:vm_options][:cpu]
          assert_equal 29095886848, @result[:vm_options][:storage][:value]
        end

        should "return the correct values from planning vm_metric_values when :mode == :reserved" do
          @vm_options = {
            :vcpus    =>{:metric => :num_cpu, :mode => :current},
            :storage  =>{:metric => :allocated_disk_storage, :mode => :current},
            :cpu      =>{:metric => :cpu_reserve, :mode => :current},
            :memory   =>{:metric => :memory_reserve, :mode => :current}
          }

          assert_nothing_raised {
            options = {:vm_options => @vm_options, :range => @options[:range]}
            @result = VimPerformancePlanning.vm_metric_values(@vm, options)
          }

          assert_equal 2,           @result[:vm_options][:vcpus][:value]
          assert_equal 0,           @result[:vm_options][:memory][:value]
          assert_equal 0,           @result[:vm_options][:cpu][:value]
          assert_equal 29095886848, @result[:vm_options][:storage][:value]
        end
      end
    end

  end

end
