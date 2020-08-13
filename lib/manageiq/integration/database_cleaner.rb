require "fileutils"

module ManageIQ
  module Integration
    class DatabaseCleaner
      SEED_CONFIG_FILENAME = File.expand_path("seed_config.yml", __dir__)

      ACTIVE_RECORD_INTERNAL_TABLES = %w[
        ar_internal_metadata
        schema_migrations
        schema_migrations_ran
      ]

      # TODO:  Determine if users/miq_user_roles can be truncated
      #
      #   miq_user_roles users ?
      #
      SKIPABLE_TABLES = %w[
        assigned_server_roles
        miq_servers
        miq_workers
        miq_databases
        server_roles
      ]

      attr_reader :seeded_tables, :skipable_tables, :truncated_tables

      # Clean the database and reset to a freshly seeded state
      def self.clean
        new.clean
      end

      # Run after a `db:seed` to generate an config that is accurate for the
      #
      # This is destructive and will drop the existing template DB.  Don't do
      # if database has been modified post seed.
      #
      def self.setup!(force: false)
        FileUtils.rm_rf(SEED_CONFIG_FILENAME) if force
        new.prepare
      end

      def initialize
        load_seed_config
      end

      def clean
        truncate_tables
        reseed
      end

      def prepare
        drop_template_db
        create_template_db
        enable_postgres_fdw
      end

      # Generates a configuration that is created after a db:seed to determine
      # what tables are seeded, as well as include tables that can't be dropped
      # mid test run (miq_servers, miq_workers, etc.) since they are currently
      # being used by the running processes for state.
      #
      # Key types include:
      #
      # - seeded_tables:      Tables that are seedable (need data after truncate)
      # - skipable_tables:    Tables that can't be dropped (name pending)
      # - truncatable_tables: Tables that can be dropped
      #
      def generate_seed_config
        return if File.exist?(SEED_CONFIG_FILENAME)

        require 'yaml'

        File.write(SEED_CONFIG_FILENAME, seed_config.to_yaml)
      end

      def load_seed_config
        if File.exist?(SEED_CONFIG_FILENAME)
          @seed_config        = YAML.load_file(SEED_CONFIG_FILENAME)
          @seeded_tables      = @seed_config[:seeded_tables]
          @skipable_tables    = @seed_config[:skipable_tables]
          @truncatable_tables = @seed_config[:truncatable_tables]
        else
          generate_seed_config
        end
      end

      private

      def seed_config
        @seed_config ||= {
          :seeded_tables      => determine_seeded_tables,
          :skipable_tables    => skipable_tables,
          :truncatable_tables => truncatable_tables
        }
      end

      def pg_conn
        ActiveRecord::Base.connection
      end

      def template_dbname
        "#{ActiveRecord::Base.connection_config[:database]}_template"
      end

      def create_template_db
        create_config = {
          :owner     => ActiveRecord::Base.connection_config[:username],
          :encodiing => ActiveRecord::Base.connection_config[:encoding],
          :template  => ActiveRecord::Base.connection_config[:database]
        }

        pg_conn.create_database(template_dbname, create_config)
      end

      def drop_template_db
        pg_conn.drop_database(template_dbname)
      end

      # Creates enables the extension for PostgreSQL's Foreign Data Wrapper
      # (named 'seed_server') and creates a connection to the template server
      # to import the base data after each test run.
      #
      #   https://www.postgresql.org/docs/10/postgres-fdw.html
      #
      # Also creates a SCHEMA namsed 'seed_tables'
      #
      def enable_postgres_fdw
        pg_conn.enable_extension("postgres_fdw")

        data_wrapper_server_options = {
          :host   => ActiveRecord::Base.connection_config[:host] || 'localhost',
          :dbname => template_dbname
        }.delete_nils.map { |k, v| "#{k} '#{v}'" }.join(", ")

        data_wrapper_user_auth_options = {
          :user     => ActiveRecord::Base.connection_config[:username],
          :password => ActiveRecord::Base.connection_config[:password]
        }.delete_nils.map { |k, v| "#{k} '#{v}'" }.join(", ")

        pg_conn.execute <<~QUERY

          DROP   SERVER IF EXISTS seed_server CASCADE;
          CREATE SERVER seed_server
                FOREIGN DATA WRAPPER postgres_fdw
                OPTIONS (#{data_wrapper_server_options});

          CREATE USER MAPPING FOR CURRENT_USER
               SERVER seed_server
              OPTIONS (#{data_wrapper_user_auth_options});


          DROP   SCHEMA IF EXISTS seed_tables;
          CREATE SCHEMA seed_tables;

          IMPORT FOREIGN SCHEMA public
            FROM SERVER seed_server
            INTO seed_tables;
        QUERY
      end

      def truncate_tables
        query = truncatable_tables.map { |table| "TRUNCATE TABLE public.#{table} RESTART IDENTITY" }
                                  .join(";\n")

        pg_conn.execute(query)
        # truncatable_tables.each { |table| pg_conn.truncate(table) }
      end

      def reseed
        @reseed_query ||= seeded_tables.map { |table|
                            columns = pg_conn.columns(:miq_sets).map(&:name).join(", ")
                            "INSERT INTO public.#{table} SELECT * FROM seed_tables.#{table};"
                          }.join("\n")

        pg_conn.execute(@reseed_query)
      end

      def all_tables
        @all_tables ||= pg_conn.tables
      end

      # Fetch the counts for all of the tables for this MIQ database (ignoring
      # ones that generated by ActiveRecord) and then rejecting ones that empty
      # (count of 0).
      def determine_seeded_tables
        return @seeded_tables if @seeded_tables

        query          = table_counts_query(truncatable_tables)
        @seeded_tables = pg_conn.select_all(query)
                                .rows.to_h
                                .reject { |_,v| v == 0 }
                                .keys
      end

      # Tables that are seeded, but will need to remain unchanged in the
      # database so the MiqServer can remain functional between specs
      #
      def skipable_tables
        @skipable_tables ||= SKIPABLE_TABLES
      end

      # Tables that can be truncated
      #
      def truncatable_tables
        return @truncatable_tables if @truncatable_tables

        @truncatable_tables  = all_tables
        @truncatable_tables -= ACTIVE_RECORD_INTERNAL_TABLES
        @truncatable_tables -= SKIPABLE_TABLES
      end

      # Generate a query to get an accurate count of all of the of the tables
      # in the database by creating a "UNION query" of the table_name + COUNT.
      #
      # Note:  Not using pg_class for this since it is documented that
      # `reltuples` is only an estimate:
      #
      #   https://www.postgresql.org/docs/10/catalog-pg-class.html
      #
      def table_counts_query(tables = all_tables)
        tables.map { |table| "SELECT '#{table}' as table, COUNT(id) count FROM #{table}" }
              .join("\n  UNION\n")
      end
    end
  end
end
