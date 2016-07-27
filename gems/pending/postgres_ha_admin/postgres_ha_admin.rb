require 'util/postgres_dsn_parser'

module PostgresHaAdmin
  DB_YML_FILE = 'failover_databases.yml'.freeze
  attr_reader :yml_file

  def init_config_dir(config_dir)
    @yml_file = Pathname.new(config_dir).join(DB_YML_FILE)
  end
end
