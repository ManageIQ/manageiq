namespace :test do
  namespace :miq_benchmark do
    task :setup do
      # Don't know why I am doing this in a seperate process... but I am... and it seems to work
      exec <<-SCRIPT
        export RAILS_USE_MEMORY_STORE=1;
        export DISABLE_DATABASE_ENVIRONMENT_CHECK=1;
        export RAILS_ENV=production;
        export ERB_IN_CONFIG=1;
        bundle exec rake db:create db:environment:set db:migrate > /dev/null;
      SCRIPT
    end
  end

  desc "Task description"
  task :miq_benchmark do
    mem_benchmark_test_file = File.expand_path "../../miq_benchmark/mem_full_load_benchmark.rb", __FILE__

    # Running this with exec since we replace the current process with a new
    # process, even though we keep the same PID.  See:
    #
    #     https://ruby-doc.org/core-2.4.0/Kernel.html#method-i-exec
    #
    # Allowing us to start fresh with the ruby memory poll.
    exec "bundle exec ruby #{mem_benchmark_test_file}"

    # test scripts
    # exec %Q{bundle exec ruby -e 'puts "#{mem_benchmark_test_file}"'}
    # exec %Q{bundle exec ruby -e 'require "bigdecimal"; require "sys/proctable"; puts $$; puts (Sys::ProcTable.ps($$).rss/::BigDecimal.new(1_048_576)).to_f'}
  end
end
