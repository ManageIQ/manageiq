module Vmdb::Loggers
  class NullLogger < Logger
    def initialize(*)
      super('/dev/null')
      self.level = Logger::UNKNOWN
    end

    def filename(*); end

    def log_backtrace(*); end

    def log_hashes(*); end

    def success(*); end

    def failure(*); end

    def instrument(*)
      yield if block_given?
    end
  end
end
