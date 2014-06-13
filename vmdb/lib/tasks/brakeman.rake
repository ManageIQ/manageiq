namespace :brakeman do
  desc "Run Brakeman"
  task :run do |t, args|
    require "brakeman"

    if ENV["CC_BUILD_ARTIFACTS"] && File.exist?(ENV["CC_BUILD_ARTIFACTS"])
      output_directory = Pathname.new(ENV["CC_BUILD_ARTIFACTS"])
    else
      output_directory = Rails.root
    end

    html_report = output_directory.join("brakeman.html").to_s
    output_files = [html_report]

    #Run Brakeman scan. Returns Tracker object.
    #
    #Options:
    #  * :app_path - path to root of Rails app (required)
    #  * :assume_all_routes - assume all methods are routes (default: true)
    #  * :check_arguments - check arguments of methods (default: true)
    #  * :collapse_mass_assignment - report unprotected models in single warning (default: true)
    #  * :combine_locations - combine warning locations (default: true)
    #  * :config_file - configuration file
    #  * :escape_html - escape HTML by default (automatic)
    #  * :exit_on_warn - return false if warnings found, true otherwise. Not recommended for library use (default: false)
    #  * :highlight_user_input - highlight user input in reported warnings (default: true)
    #  * :html_style - path to CSS file
    #  * :ignore_model_output - consider models safe (default: false)
    #  * :interprocedural - limited interprocedural processing of method calls (default: false)
    #  * :message_limit - limit length of messages
    #  * :min_confidence - minimum confidence (0-2, 0 is highest)
    #  * :output_files - files for output
    #  * :output_formats - formats for output (:to_s, :to_tabs, :to_csv, :to_html)
    #  * :parallel_checks - run checks in parallel (default: true)
    #  * :print_report - if no output file specified, print to stdout (default: false)
    #  * :quiet - suppress most messages (default: true)
    #  * :rails3 - force Rails 3 mode (automatic)
    #  * :report_routes - show found routes on controllers (default: false)
    #  * :run_checks - array of checks to run (run all if not specified)
    #  * :safe_methods - array of methods to consider safe
    #  * :skip_libs - do not process lib/ directory (default: false)
    #  * :skip_checks - checks not to run (run all if not specified)
    #  * :absolute_paths - show absolute path of each file (default: false)
    #  * :summary_only - only output summary section of report
    #                    (does not apply to tabs format)

    # * Note: :only_files is useful for quickly testing various brakeman settings on a small subset of the codebase:
    #         :only_files => Dir.glob(Rails.root.join("app/models/miq_server*.rb"))
    options = {
      :app_path       => ".",
      :output_files   => output_files,
      :quiet          => false,
      :absolute_paths => true
    }

    tracker = Brakeman.run(options)

    # Exit 1 on any warnings so cruisecontrol.rb can report the project as red.
    exit tracker.checks.all_warnings.empty? ? 0 : 1
  end
end
