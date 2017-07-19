require 'trollop'
require 'pg'
require 'pg_inspector/error'
require 'pg_inspector/pg_inspector_operation'
require 'pg_inspector/util'

module PgInspector
  class ActiveConnectionsYAML < PgInspectorOperation
    HELP_MSG_SHORT = "Dump avtive connections to YAML file".freeze
    def parse_options(args)
      self.options = Trollop.options(args) do
        opt(:pg_host, "PostgreSQL host name or address",
            :type => :string, :short => "s", :default => "127.0.0.1")
        opt(:user, "PostgreSQL user",
            :type => :string, :short => "u", :default => "postgres")
        opt(:port, "PostgreSQL server port",
            :short => "p", :default => 5432)
        opt(:output, "Output file",
            :type => :string, :short => "o", :default => "active_connections.yml")
        opt(:ignore_error, "Ignore incomplete application name column",
            :short => "i")
        opt(:only_miq_rows, "Get only ManageIQ Server/Worker rows",
            :short => "m")
      end
    end

    def run
      Util.dump_to_yml_file(
        filter_by_application_name(
          pg_stat_activity_rows_to_array(
            rows_in_pg_stat_activity(
              connect_pg_server
            )
          )
        ), "active connections", options[:output]
      )
    rescue Error::ApplicationNameIncompleteError => e
      Util.error_exit(e)
    end

    private

    def connect_pg_server
      conn_options = {
        :dbname => 'vmdb_production',
        :host   => options[:pg_host],
        :port   => options[:port]
      }
      if options[:user]
        conn_options[:user] = options[:user]
      end
      options[:password] = Util.ask_for_password_or_none(
        "Please enter password for PostgreSQL user #{options[:user]}:"
      )
      unless options[:password].empty?
        conn_options[:password] = options[:password]
      end
      PG::Connection.open(conn_options)
    rescue PG::Error => e
      Util.error_exit(e)
    end

    def rows_in_pg_stat_activity(conn)
      query = <<-SQL
SELECT *
FROM pg_stat_activity
ORDER BY application_name;
SQL
      conn.exec_params(query)
    rescue PG::Error => e
      Util.error_exit(e)
    end

    def pg_stat_activity_rows_to_array(rows)
      result = []
      rows.each { |row| result << row }
      result
    end

    def filter_by_application_name(rows_array)
      unless options[:all_rows]
        rows_array = rows_array.select { |row| row["application_name"].start_with?('MIQ') }
      end

      rows_array.each do |row|
        next unless row["application_name"].end_with?('..')
        error_msg = "The application name for MIQ server/worker: {#app_name} is truncated"
        if options[:ignore_error]
          $stderr.puts error_msg
        else
          raise error_msg
        end
      end

      rows_array
    end
  end
end
