module Vmdb::Logging
  class MirroredLogger < VMDBLogger
    attr_accessor :mirror_logger, :mirror_prefix, :mirror_level

    def initialize(logdev, mirror_prefix, shift_age = 0, shift_size = 1048576)
      super(logdev, shift_age, shift_size)

      self.mirror_prefix = mirror_prefix
      self.mirror_level  = ERROR
      self.mirror_logger = $log if $log
    end

    def mirror?(severity)
      severity >= mirror_level
    end

    def add_with_mirror(severity, message = nil, progname = nil, msgnum = nil, &block)
      if mirror_logger && mirror?(severity)
        # The following lines of code are copied from VMDBLogger#add (which is copied from Logger#add)
        mirror_progname = progname || @progname
        if message.nil?
          if block_given?
            mirror_message = yield
          else
            mirror_message = mirror_progname
            mirror_progname = @progname
          end
        end

        mirror_logger.add(severity, "#{mirror_prefix}#{mirror_message}", mirror_progname, msgnum)
      end
      add_without_mirror(severity, message, progname, msgnum, &block)
    end
    alias add_without_mirror add
    alias add add_with_mirror
  end
end
