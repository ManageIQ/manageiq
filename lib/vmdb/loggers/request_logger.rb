module Vmdb::Loggers
  class RequestLogger

    attr_accessor :logger

    def initialize(resource_id, logger: $log)
      @resource_id = resource_id
      @logger = logger
    end

    LEVELS = [:debug, :info, :warn, :error]

    # def debug?
    # def info?
    # def warn?
    # def error?
    # def add
    # def level
    # def log_backtrace
    (LEVELS.map { |l| :"#{l}?" } + %i[add level log_backtrace]).each do |method|
      define_method(method) { |*args| logger.send(method, *args) }
    end

    LEVELS.each do |level|
      define_method(level) do |msg = nil, &blk|
        request_log(level, msg, &blk)
      end
    end

    private

    def request_log(severity, message = nil)
      # Partially copied from Logger#add
      return true unless logger.send("#{severity}?".to_sym)

      message = yield if message.nil? && block_given?

      RequestLog.create(:message => message, :severity => severity.to_s.upcase, :resource_id => @resource_id)
      logger.public_send(severity, message)
    end
  end
end