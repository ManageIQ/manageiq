require 'logger'
require 'active_support/core_ext/object/try'

class VMDBLogger < Logger
  def initialize(*args)
    super
    self.level = INFO

    # HACK: ActiveSupport monkey patches the standard Ruby Logger#initialize
    # method to set @formatter to a SimpleFormatter.
    #
    # The ActiveSupport Logger patches are deprecated in Rails 3.1.1 in favor of
    # ActiveSupport::BufferedLogger, so this hack may not be needed in future
    # version of Rails.
    self.formatter = Formatter.new
  end

  attr_reader :logdev # Expose logdev

  def logdev=(logdev)
    if @logdev
      shift_age  = @logdev.instance_variable_get(:@shift_age)
      shift_size = @logdev.instance_variable_get(:@shift_size)
      @logdev.close
    else
      shift_age  = 0
      shift_size = 1048576
    end

    @logdev = LogDevice.new(logdev, :shift_age => shift_age, :shift_size => shift_size)
  end

  def filename
    logdev.try(:filename)
  end

  alias_method :filename=, :logdev=

  def self.contents(log, width = nil, last = 1000)
    return "" unless File.file?(log)

    if last.nil?
      contents = File.open(log, "rb", &:read).split("\n")
    else
      require 'util/miq-system'
      contents = MiqSystem.tail(log, last)
    end
    return "" if contents.nil? || contents.empty?

    results = []

    # Wrap lines at width if passed
    contents.each do |line|
      while !width.nil? && line.length > width
        # Don't return lines containing invalid UTF8 byte sequences - see vmdb_logger_test.rb
        results.push(line[0...width]) if (line[0...width].unpack("U*") rescue nil)
        line = line[width..line.length]
      end
      # Don't return lines containing invalid UTF8 byte sequences - see vmdb_logger_test.rb
      results.push(line) if line.length && (line.unpack("U*") rescue nil)
    end

    # Put back the utf-8 encoding which is the default for most rails libraries
    # after opening it as binary and getting rid of the invalid UTF8 byte sequences
    results.join("\n").force_encoding("utf-8")
  end

  def contents(width = nil, last = 1000)
    self.class.contents(filename, width, last)
  end

  def log_backtrace(err, level = :error)
    # Get the name of the method that called us unless it is a wrapped log_backtrace
    method_name = nil
    caller.each do |c|
      method_name = c[/`([^']*)'/, 1]
      break unless method_name == 'log_backtrace'
    end

    # Log the error text
    send(level, "[#{err.class.name}]: #{err.message}  Method:[#{method_name}]")

    # Log the stack trace except for some specific exceptions
    unless (Object.const_defined?(:MiqException) && err.kind_of?(MiqException::Error)) ||
           (Object.const_defined?(:MiqAeException) && err.kind_of?(MiqAeException::Error))
      send(level, err.backtrace.nil? || err.backtrace.empty? ? "Backtrace is not available" : err.backtrace.join("\n"))
    end
  end

  def self.log_hashes(logger, h, options = {})
    level  = options[:log_level] || :info
    filter = [options[:filter]].flatten.compact.map(&:to_s) << "password"
    filter.uniq!

    YAML.dump(h).split("\n").each do |l|
      next if l[0...3] == '---'
      logger.send(level, "  #{l}") unless filter.any? { |f| l.include?(f) }
    end
  end

  def log_hashes(h, options = {})
    self.class.log_hashes(self, h, options)
  end

  private

  class Formatter < Logger::Formatter
    FORMAT = "[----] %s, [%s#%d:%x] %5s -- %s: %s\n"

    def call(severity, time, progname, msg)
      msg = msg2str(msg)

      # Add task id to the message if a task is currently being worked on.
      if $_miq_worker_current_msg && !$_miq_worker_current_msg.task_id.nil?
        prefix = "Q-task_id([#{$_miq_worker_current_msg.task_id}])"
        msg = "#{prefix} #{msg}" unless msg.include?(prefix)
      end

      FORMAT % [severity[0..0], format_datetime(time), $$, Thread.current.object_id, severity, progname, msg]
    end
  end
end
