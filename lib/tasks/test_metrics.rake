# NOTE: Disabled out of box metric_fu task, :metrics_all
#   metrics:all task is copied and split into metrics:configuration and
#   metrics:run tasks below to expose the configuration for manipulation
#   original here: https://github.com/ManageIQ/metric_fu/blob/master/tasks/metric_fu.rake
require_relative "./evm_test_helper"

if defined?(RSpec)
namespace :test do
  desc "Run metrics using metric_fu"
  task :metrics => %w(test:initialize test:metrics:check_env test:metrics:configuration) do
    begin
      puts "** #{Time.now} Running 'test:vmdb'"
      Rake::Task['test:vmdb'].invoke if MetricFu.configuration.metrics.include?(:rcov)
    ensure
      puts "** #{Time.now} Running 'test:vmdb'...Complete"
      Rake::Task['test:metrics:run'].invoke
    end
  end

  namespace :metrics do
    task :setup => %w(test:initialize test:metrics:check_env test:setup_db)

    task :check_env => :environment do
      if Rails.env != 'metric_fu'
        raise "Invalid environment '#{Rails.env}'.  Run with RAILS_ENV=metric_fu instead."
      end
    end

    task :configuration do
      STDOUT.sync = true

      MetricFu::Configuration.run do |config|
        config.flog[:show_call_list] = false

        config.rcov[:external] = Rails.root.join('tmp/metric_fu/coverage/rcov/rcov.txt').to_s

        config.saikuro[:filter_cyclo] = "10"
        config.saikuro[:warn_cyclo]   = "10"
        config.saikuro[:error_cyclo]  = "15"
        config.syntax_highlighting    = false
      end

      # Uncomment and edit the following to only run specific tests
      # MetricFu.configuration.metrics = [:churn, :flog, :flay, :reek, :roodi, :rcov, :hotspots, :saikuro, :stats, :rails_best_practices]

      # TODO: rails_best_practices blows up an invalid byte sequence in UTF-8 error and doesn't report the file with the issue
      # need to instrument it to report the failing files and prevent this error from blowing all the metrics
      #
      # ./gems/rails_best_practices-1.10.1/lib/rails_best_practices/lexicals/remove_tab_check.rb:19:in `check': invalid byte sequence in UTF-8 (ArgumentError)
      #   from ./gems/rails_best_practices-1.10.1/lib/rails_best_practices/core/checking_visitor.rb:39:in `block in lexical'
      #   from ./gems/rails_best_practices-1.10.1/lib/rails_best_practices/core/checking_visitor.rb:38:in `each'
      #   from ./gems/rails_best_practices-1.10.1/lib/rails_best_practices/core/checking_visitor.rb:38:in `lexical'
      #   from ./gems/rails_best_practices-1.10.1/lib/rails_best_practices/core/runner.rb:64:in `lexical'
      #   from ./gems/rails_best_practices-1.10.1/lib/rails_best_practices/core/runner.rb:71:in `lexical_file'
      #   from ./gems/rails_best_practices-1.10.1/lib/rails_best_practices/analyzer.rb:82:in `block in process'
      #   from ./gems/rails_best_practices-1.10.1/lib/rails_best_practices/analyzer.rb:81:in `each'
      #   from ./gems/rails_best_practices-1.10.1/lib/rails_best_practices/analyzer.rb:81:in `process'
      #   from ./gems/rails_best_practices-1.10.1/lib/rails_best_practices/analyzer.rb:248:in `block in analyze_source_codes'
      #   from ./gems/rails_best_practices-1.10.1/lib/rails_best_practices/analyzer.rb:248:in `each'
      #   from ./gems/rails_best_practices-1.10.1/lib/rails_best_practices/analyzer.rb:248:in `analyze_source_codes'
      #
      # Which then blows up the metric result processing with this error:
      #   You have a nil object when you didn't expect it!
      #   You might have expected an instance of Array.
      #   The error occurred while evaluating nil.first
      #   ./vmdb/vendor/gems/metric_fu-3.0.0/lib/generators/rails_best_practices.rb:11:in `analyze'
      #   ./vmdb/vendor/gems/metric_fu-3.0.0/lib/base/generator.rb:130:in `block in generate_report'
      #   ./vmdb/vendor/gems/metric_fu-3.0.0/lib/base/generator.rb:128:in `each'
      #   ./vmdb/vendor/gems/metric_fu-3.0.0/lib/base/generator.rb:128:in `generate_report'
      #   ./vmdb/vendor/gems/metric_fu-3.0.0/lib/base/report.rb:60:in `add'
      MetricFu.configuration.metrics.delete(:rails_best_practices)
      MetricFu.configuration.metrics.delete(:reek)  # takes 30+ minutes and isn't that useful
      MetricFu.configuration.metrics.delete(:roodi) # takes 1-2 minutes and duplicates features from other metrics

      # Remove graph data for everything but the 14 most recent builds since
      # metric_fu graphs don't display more data points properly.
      files = Dir[File.join(MetricFu.data_directory, '*.yml')].sort[0..-15]
      FileUtils.rm_f(files, :verbose => true)
    end

    task :run do
      puts "** #{Time.now} Running MetricFu..."

      # copy of the metrics:all task from metric_fu with logging
      MetricFu.metrics.each do |metric|
        puts "** #{Time.now} Running MetricFu.report.add(#{metric})"
        MetricFu.report.add(metric)
      end

      puts "** #{Time.now} Running MetricFu.report.save_output to #{MetricFu.base_directory}"
      MetricFu.report.save_output(
        MetricFu.report.to_yaml,
        MetricFu.base_directory,
        "report.yml"
      )

      puts "** #{Time.now} Running MetricFu.report.save_output to #{MetricFu.data_directory}"
      MetricFu.report.save_output(
        MetricFu.report.to_yaml,
        MetricFu.data_directory,
        "#{Time.now.strftime("%Y%m%d")}.yml"
      )

      puts "** #{Time.now} Running MetricFu.report.save_templatized_report"
      MetricFu.report.save_templatized_report

      MetricFu.graphs.each do |graph|
        puts "** #{Time.now} Running MetricFu.graph.add(#{graph}, #{MetricFu.graph_engine})"
        MetricFu.graph.add(graph, MetricFu.graph_engine)
      end

      puts "** #{Time.now} Running MetricFu.graph.generate"
      MetricFu.graph.generate

      if MetricFu.report.open_in_browser?
        MetricFu.report.show_in_browser(MetricFu.output_directory)
      end

      # To debug rcov failures: Copy the rcov.txt to the cc.rb custom build artifacts
      if ENV['CC_BUILD_ARTIFACTS'] && File.exist?(ENV['CC_BUILD_ARTIFACTS'])
        src  = MetricFu.configuration.rcov[:external]
        dest = File.join(ENV['CC_BUILD_ARTIFACTS'], 'rcov.txt')
        FileUtils.cp(src, dest) if File.exist?(src)
      end

      puts "** #{Time.now} Running MetricFu...Complete"
    end
  end
end
end # ifdef
