class EvmDatabase
  include Vmdb::Logging

  SCHEMA_FILE = Rails.root.join("db/schema.yml").freeze

  PRIMORDIAL_CLASSES = %w(
    MiqDatabase
    MiqRegion
    MiqEnterprise
    Zone
    MiqServer
    ServerRole
    Tenant
    MiqProductFeature
    MiqUserRole
    MiqGroup
    User
    MiqReport
    VmdbDatabase
  )

  ORDERED_CLASSES = %w(
    RssFeed
    MiqWidget
    MiqAction
    MiqEventDefinition
    MiqPolicySet
    ChargebackRateDetailMeasure
    ChargeableField
    ChargebackRateDetailCurrency
    ChargebackRate
  ).freeze

  RAILS_ENGINE_MODEL_CLASS_NAMES = %w(MiqAeDatastore)

  def self.find_seedable_model_class_names
    @found_model_class_names ||= begin
      Dir.glob(Rails.root.join("app/models/*.rb")).collect { |f| File.basename(f, ".*").camelize if File.read(f).include?("self.seed") }.compact.sort
    end
  end

  def self.seedable_model_class_names
    ORDERED_CLASSES + (find_seedable_model_class_names - ORDERED_CLASSES) + RAILS_ENGINE_MODEL_CLASS_NAMES
  end

  def self.seed_primordial
    if ENV['SKIP_SEEDING'] && MiqDatabase.count > 0
      puts "** seedings is skipped on startup."
      puts "** Unset SKIP_SEEDING to re-enable"
    else
      seed(PRIMORDIAL_CLASSES)
    end
  end

  def self.seed_last
    if ENV['SKIP_SEEDING'] && MiqDatabase.count > 0
      seed(seedable_model_class_names - PRIMORDIAL_CLASSES)
    end
  end

  def self.seed(classes = nil, exclude_list = [])
    _log.info("Seeding...")

    classes ||= PRIMORDIAL_CLASSES + (seedable_model_class_names - PRIMORDIAL_CLASSES)
    classes -= exclude_list

    # Only 1 machine can go through this at a time
    # Populating the DB takes 20 seconds
    # Not populating the db takes 3 seconds
    MiqDatabase.with_lock(10.minutes) do
      classes.each do |klass|
        begin
          klass = klass.constantize if klass.kind_of?(String)
        rescue => err
          _log.log_backtrace(err)
          raise
        end

        if klass.respond_to?(:seed)
          _log.info("Seeding #{klass}")
          begin
            klass.seed
          rescue => err
            _log.log_backtrace(err)
            raise
          end
        else
          _log.error("Class #{klass} does not have a seed")
        end
      end
    end

    _log.info("Seeding... Complete")
  end

  def self.host
    Rails.configuration.database_configuration[Rails.env]['host']
  end

  def self.local?
    host.blank? || ["localhost", "localhost.localdomain", "127.0.0.1", "0.0.0.0"].include?(host)
  end

  # Determines the average time to the database in milliseconds
  def self.ping(connection = ApplicationRecord.connection)
    query = "SELECT 1"
    Benchmark.realtime { 10.times { connection.select_value(query) } } / 10 * 1000
  end

  # Determines if the schema currently being used is the same as the one we expect
  #
  # @param connection Check the database at this connection against the local file
  # @return nil if the schemas match, an error message otherwise
  def self.check_schema(connection = ActiveRecord::Base.connection)
    check_schema_tables(connection) || check_schema_columns(connection)
  end

  # Writes the schema to SCHEMA_FILE as it currently exists in the database
  #
  # @param connection Write the schema at this connection to the file
  def self.write_expected_schema(connection = ActiveRecord::Base.connection)
    File.write(SCHEMA_FILE, current_schema(connection).to_yaml)
  end

  def self.raise_server_event(event)
    msg = "Server IP: #{MiqServer.my_server.ipaddress}, Server Host Name: #{MiqServer.my_server.hostname}"
    MiqEvent.raise_evm_event_queue(MiqServer.my_server, event, :event_details => msg)
  end

  class << self
    private

    def expected_schema
      YAML.load_file(SCHEMA_FILE)
    end

    def current_schema(connection)
      connection.tables.sort.each_with_object({}) do |t, h|
        h[t] = connection.columns(t).map(&:name)
      end
    end

    def check_schema_columns(connection)
      compare_schema = current_schema(connection)

      errors = []
      expected_schema.each do |table, expected_columns|
        next if compare_schema[table] == expected_columns

        errors << <<-ERROR.gsub!(/^ +/, "")
          Schema validation failed for host #{db_connection_host(connection)}:

          Columns for table #{table} in the current schema do not match the columns listed in #{SCHEMA_FILE}

          expected:
          #{expected_columns.inspect}

          got:
          #{compare_schema[table].inspect}
        ERROR
      end
      errors.empty? ? nil : errors.join("\n")
    end

    def check_schema_tables(connection)
      current_tables  = current_schema(connection).keys - MiqPglogical::ALWAYS_EXCLUDED_TABLES
      expected_tables = expected_schema.keys - MiqPglogical::ALWAYS_EXCLUDED_TABLES

      return if current_tables == expected_tables

      diff_in_current  = current_tables - expected_tables
      diff_in_expected = expected_tables - current_tables
      if diff_in_current.empty? && diff_in_expected.empty?
        <<-ERROR.gsub!(/^ +/, "")
          Schema validation failed for host #{db_connection_host(connection)}:

          Expected schema table order does not match sorted current tables.
          Use 'rake evm:db:write_schema' to generate the new expected schema when making changes.
        ERROR
      else
        <<-ERROR.gsub!(/^ +/, "")
          Schema validation failed for host #{db_connection_host(connection)}:

          Current schema tables do not match expected

          Additional tables in current schema: #{diff_in_current}
          Missing tables in current schema: #{diff_in_expected}
        ERROR
      end
    end

    def db_connection_host(connection)
      connection.raw_connection.conninfo_hash[:host] || "localhost"
    end
  end
end
