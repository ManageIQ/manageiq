require 'util/postgres_dsn_parser'

module PostgresHaAdmin

  class << self
    attr_writer :logger
  end

  def self.logger
    @logger ||= NullLogger.new
  end

end