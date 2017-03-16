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
    # exec "bundle exec ruby #{mem_benchmark_test_file}"
    exec <<-SCRIPT
      bundle exec ruby -e 'puts "#{mem_benchmark_test_file}"';

      echo "shell out to ps..."
      bundle exec ruby -e '
        require "bigdecimal";
        puts "Pid: \#{$$}";
        puts "before: \#{((BigDecimal.new(%x{ps -o rss= -p \#{$$}}) * 1024)/::BigDecimal.new(1_048_576)).to_f}";
        require "rbvmomi"
        puts "after:  \#{((BigDecimal.new(%x{ps -o rss= -p \#{$$}}) * 1024)/::BigDecimal.new(1_048_576)).to_f}";';
      echo;

      echo "Using sys/proctable...";
      bundle exec ruby -e '
        require "bigdecimal";
        require "sys/proctable";
        puts "Pid: \#{$$}";
        puts "before: \#{(Sys::ProcTable.ps($$).rss/::BigDecimal.new(1_048_576)).to_f}";
        require "rbvmomi"
        puts "after: \#{(Sys::ProcTable.ps($$).rss/::BigDecimal.new(1_048_576)).to_f}";';
      echo;

      echo "GemProcessMem method..."
      bundle exec ruby -e '
        require "bigdecimal";
        def linux_status_memory;
          file = Pathname.new("/proc/\#{$$}/status");
          line = file.each_line.detect {|line| line.start_with? "VmRSS".freeze };
          return unless line;
          return unless (_name, value, unit = line.split(nil)).length == 3;
          {"kb" => 1024, "mb" => 1_048_576, "gb" => 1_073_741_824}[unit.downcase!] * value.to_i;
        rescue Errno::EACCES, Errno::ENOENT;
          0;
        end;
        puts "Pid: \#{$$}";
        puts "before: \#{(linux_status_memory/::BigDecimal.new(1_048_576)).to_f;}"
        require "rbvmomi"
        puts "after:  \#{(linux_status_memory/::BigDecimal.new(1_048_576)).to_f;}"';
      echo;

      echo;
      echo;
      bundle exec ruby #{mem_benchmark_test_file};
    SCRIPT

    # test scripts
    # exec %Q{bundle exec ruby -e 'puts "#{mem_benchmark_test_file}"'}
    # exec %Q{bundle exec ruby -e 'require "bigdecimal"; require "sys/proctable"; puts $$; puts (Sys::ProcTable.ps($$).rss/::BigDecimal.new(1_048_576)).to_f'}
  end
end
