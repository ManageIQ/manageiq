class AutomateMethodException < StandardError
end

begin
  require 'date'
  require 'rubygems'
  require 'active_support/all'
  require 'socket'
  Socket.do_not_reverse_lookup = true  # turn off reverse DNS resolution

  require 'drb'
  require 'yaml'

  Time.zone = 'UTC'

  MIQ_OK    = 0
  MIQ_WARN  = 4
  MIQ_ERROR = 8
  MIQ_STOP  = 8
  MIQ_ABORT = 16

  DRbObject.send(:undef_method, :inspect)
  DRbObject.send(:undef_method, :id) if DRbObject.respond_to?(:id)

rescue Exception => err
  STDERR.puts('The following error occurred during inline method preamble evaluation:')
  STDERR.puts("  #{err.class}: #{err.message}")
  STDERR.puts("  #{err.backtrace.join("\n")}") unless err.kind_of?(AutomateMethodException)
  raise
end

class Exception
  def backtrace_with_evm
    value = backtrace_without_evm
    $evm && value ? $evm.backtrace(value) : value
  end

  alias backtrace_without_evm backtrace
  alias backtrace backtrace_with_evm
end

class AutomateScriptRunner
  def initialize(root_binding)
    @root_binding = root_binding

    @command_pipe = IO.for_fd(4, "r")
    @status_pipe = IO.for_fd(5, "w")

    @status_pipe.sync = true
    @command_pipe.sync = true
  end

  def activate_service(miq_uri, miq_id)
    return if miq_uri == 'NONE'
    ::Object.const_set :MIQ_URI, miq_uri

    DRb.start_service("druby://127.0.0.1:0")
    $evmdrb = DRbObject.new(nil, miq_uri)
    raise AutomateMethodException,"Cannot create DRbObject for uri=#{miq_uri}" if $evmdrb.nil?

    return if miq_id == -1

    $evm = $evmdrb.find(miq_id)
    raise AutomateMethodException, "Cannot find Service for id=#{miq_id} and uri=#{miq_uri}" if $evm.nil?
    ::Object.const_set :MIQ_ARGS, $evm.inputs
  rescue Exception => err
    STDERR.puts('The following error occurred during service activation:')
    STDERR.puts("  #{err.class}: #{err.message}")
    STDERR.puts("  #{err.backtrace.join("\n")}") unless err.kind_of?(AutomateMethodException)
    raise
  end

  def execute_incoming_scripts
    @status_pipe.puts "booted"

    loop do
      first_line = @command_pipe.gets
      return if first_line.nil? # EOF
      miq_uri = first_line.chomp

      service_id = @command_pipe.gets.to_i
      raise "Sync failure [01]" if service_id == 0

      data_length = @command_pipe.gets.to_i
      raise "Sync failure [02]" unless data_length > 0

      data = @command_pipe.read(data_length)
      raise "Sync failure [03]" unless data.size == data_length

      tag = @command_pipe.gets + @command_pipe.gets
      raise "Sync failure [04]" unless tag == "\n<EOF>\n"

      @status_pipe.puts "running"

      status = execute_script(miq_uri, service_id, data)

      @status_pipe.puts status.exitstatus
    end
  end

  def clear_child_environment
    @command_pipe.close
    @status_pipe.close

    ::Object.send :remove_const, :AutomateScriptRunner
  end

  def execute_script(miq_uri, service_id, data)
    pid = fork do
      activate_service miq_uri, service_id
      clear_child_environment

      begin
        @root_binding.eval(data, "<ae-method>", 1)
      rescue SystemExit
        raise
      rescue Exception => err
        if $evm
          $evm.log('error', 'The following error occurred during method evaluation:')
          $evm.log('error', "  #{err.class}: #{err.message}")
          $evm.log('error', "  #{err.backtrace[0..-2].join("\n")}")
        end
        raise
      ensure
        $evm.disconnect_sql if $evm
      end
    end

    _, status = Process.waitpid2(pid)

    status
  end
end

AutomateScriptRunner.new(binding).execute_incoming_scripts
