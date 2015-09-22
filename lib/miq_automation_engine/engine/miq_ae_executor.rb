require 'monitor'

module MiqAeEngine
  class MiqAeExecutor
    class InternalError < RuntimeError
    end

    class UsageError < RuntimeError
    end

    include MonitorMixin

    def initialize
      super

      launch

      rc, _stdout, _stderr = run_ruby('nil')
      raise InternalError, "Ready failure" unless rc == 0
    end

    #--
    # We're not using #synchronize, because that would block; an
    # attempted double-usage is an error
    def exclusively
      raise UsageError, "Executor in use" unless mon_try_enter

      begin
        yield
      ensure
        mon_exit
      end
    end

    def run_ruby(ruby_code, miq_uri = 'NONE', service_id = -1)
      exclusively do
        @command.puts miq_uri
        @command.puts service_id
        @command.puts ruby_code.bytesize
        @command.write ruby_code
        @command.puts
        @command.puts '<EOF>'
        raise InternalError, "Sync failure [00]" unless @complete.gets == "running\n"
        rc = @complete.gets.to_i

        format_result(rc)
      end
    end

    def format_result(rc)
      [rc, @out_buffer.slice, @err_buffer.slice]
    end

    def stop
      Process.kill 'TERM', @pid
      Process.wait @pid

      @out_buffer.join
      @err_buffer.join
    end

    private

    def setup_io_redirections
      command_in, @command = IO.pipe
      @complete, complete_out = IO.pipe

      @command.sync = true
      @complete.sync = true

      @out_buffer = LineBuffer.new { |msg| $miq_ae_logger.info  "Method STDOUT: #{msg}" }
      @err_buffer = LineBuffer.new { |msg| $miq_ae_logger.error "Method STDERR: #{msg}" }

      {
        :out => @out_buffer.pipe,
        :err => @err_buffer.pipe,
        4    => command_in,
        5    => complete_out,
      }
    end

    def launch
      fds = setup_io_redirections

      Bundler.with_clean_env do
        @pid = spawn(
          Gem.ruby,
          "-I", File.join(Gem.loaded_specs['activesupport'].full_gem_path, 'lib'),
          File.expand_path('../miq_ae_executor_body.rb', __FILE__),

          fds.merge(:in => :close)
        )

        fds.values.each(&:close)
      end

      raise InternalError, "Boot failure" unless @complete.gets == "booted\n"
    end

    class LineBuffer
      attr_reader :pipe
      def initialize
        @buffer = ''

        input, @pipe = IO.pipe

        @thread = Thread.new do
          while (s = input.gets)
            @buffer << s
            yield s
          end
        end
      end

      def slice
        previous, @buffer = @buffer, ''
        previous
      end

      def join
        @thread.join
      end
    end
  end
end
