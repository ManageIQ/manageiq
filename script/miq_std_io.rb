class MiqStdIoFile < File
  def write(str, keep = false)
    super(str) if keep
  end
end

class MiqStdIo
  rails_root = defined?(Rails) ? Rails.root : File.join(File.dirname(__FILE__), "../")
  IO_DOLLAR_STDOUT = File.join(rails_root, "data/verify_db_dollar_stdout")
  IO_DOLLAR_STDERR = File.join(rails_root, "data/verify_db_dollar_stderr")
  IO_STDOUT = File.join(rails_root, "data/verify_db_stdout")
  IO_STDERR = File.join(rails_root, "data/verify_db_stderr")

  def self.log_std_io(count)
    $orig_stdout.puts "#{count} $stderr == $orig_stderr: #{$stderr == $orig_stderr}"
    $orig_stdout.puts "#{count} $stdout == $orig_stdout: #{$stdout == $orig_stdout}"
  end

  def self.std_io_to_files(&blk)
    # Redirect standard output and error to a file so we capture only ruby output
    # The PG gem outputs messages when creating tables which we cannot prevent from being returned as the output of the script
    # NOTICE:  CREATE TABLE / PRIMARY KEY will create implicit index "vim_performance_counters_pkey" for table "vim_performance_counters"

#    $stdout.flush
#    $stderr.flush
    $orig_stdout, $orig_stderr = $stdout, $stderr
    #$orig_cap_stdout, $orig_cap_stderr = STDOUT, STDERR
    #log_std_io(1)
    begin
      # We want all standard output from the commands but not standard error
      $stdout = File.new(IO_DOLLAR_STDOUT, 'a+')
      $stderr = MiqStdIoFile.new(IO_DOLLAR_STDERR, 'a+')
      #Object.const_set(:STDOUT, File.new(IO_STDOUT, 'a'))
      #Object.const_set(:STDERR, File.new(IO_STDERR, 'a'))
      #log_std_io(2)
      yield
    ensure
      #log_std_io(3)
#      $stdout.flush
#      $stderr.flush
      $stdout.close
      $stderr.close
      $stdout = $orig_stdout
      $stderr = $orig_stderr
      #Object.const_set(:STDOUT, $orig_cap_stdout)
      #Object.const_set(:STDERR, $orig_cap_stderr)
      #log_std_io(4)
    end
  end
end



