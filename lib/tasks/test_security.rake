namespace :test do
  namespace :security do
    task :setup # NOOP - Stub for consistent CI testing

    desc "Run Brakeman"
    task :brakeman do
      require "brakeman"

      # See all possible options here:
      #   http://www.rubydoc.info/gems/brakeman/Brakeman#run-class_method
      tracker = Brakeman.run(
        :app_path     => ".",
        :quiet        => false,
        :print_report => true
      )

      # Exit 1 on any warnings so CI can report the project as red.
      exit tracker.filtered_warnings.empty? ? 0 : 1
    end

    desc "Run bundler audit"
    task :bundler_audit do
      begin
        require 'awesome_spawn'
        puts AwesomeSpawn.run!("bundle-audit check", :params => {:update => nil, :verbose => nil}).output
      rescue AwesomeSpawn::CommandResultError => err
        puts "[#{err.result.command_line.inspect}] exited: [#{err.result.exit_status}] with:"
        puts err.result.output
        puts err.result.error
        exit err.result.exit_status
      end
    end
  end

  desc "Run security tests"
  task :security => %w(security:bundler_audit security:brakeman)
end
