module Vmdb::Loggers
  class IoLogger < StringIO
    def initialize(logger, level = :info, prefix = nil)
      @logger = logger
      @level  = level
      @prefix = prefix
      super()
    end

    def write(*args)
      args.each do |arg|
        @buffer ||= ""
        @buffer << arg
        dump_buffer if arg.include?("\n")
      end
    end

    def <<(string)
      write(string)
    end

    private

    def dump_buffer
      @buffer.each_line do |l|
        next if l.empty?
        line = [@prefix, l].join(" ").strip
        @logger.send(@level, line)
      end
      @buffer = nil
    end
  end
end
