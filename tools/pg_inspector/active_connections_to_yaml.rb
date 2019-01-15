require 'optimist'
require 'pg'
require 'pg_inspector/error'
require 'pg_inspector/pg_inspector_operation'
require 'pg_inspector/util'

module PgInspector
  class ActiveConnectionsYAML < PgInspectorOperation
    HELP_MSG_SHORT = "Dump active connections to YAML file".freeze
    def parse_options(args)
      self.options = Optimist.options(args) do
        banner <<-BANNER

#{HELP_MSG_SHORT}

Use password in PGPASSWORD environment variable if no password file given.

Options:
BANNER
        opt(:pg_host, "PostgreSQL host name or address",
            :type => :string, :short => "s", :default => "127.0.0.1")
        opt(:port, "PostgreSQL server port",
            :short => "p", :default => 5432)
        opt(:user, "PostgreSQL user",
            :type => :string, :short => "u", :default => "root")
        opt(:database, "Database to output stat activity, with `-m' to only output activity for this Database",
            :type => :string, :short => "d", :default => "postgres")
        opt(:output, "Output file",
            :type => :string, :short => "o", :default => DEFAULT_OUTPUT_PATH.join("#{PREFIX}active_connections.yml").to_s)
        opt(:output_locks, "Output lock file",
            :type => :string, :short => "l", :default => DEFAULT_OUTPUT_PATH.join("#{PREFIX}locks.yml").to_s)
        opt(:password_file, "File content to use as password",
            :type => :string, :short => "f")
        opt(:ignore_error, "Ignore incomplete application name column",
            :short => "i")
        opt(:only_miq_rows, "Get only ManageIQ Server/Worker rows",
            :short => "m")
      end
    end

    def run
      conn = connect_pg_server
      Util.dump_to_yml_file(
        filter_by_application_name(
          filter_by_database_name(
            pg_rows_to_array(
              rows_in_table(
                conn, "pg_stat_activity", "application_name"
              )
            )
          )
        ), "active connections", options[:output]
      )
      Util.dump_to_yml_file(
        pg_rows_to_array(
          rows_in_table(
            conn, "pg_locks"
          )
        ), "locks information", options[:output_locks]
      )
    rescue Error::ApplicationNameIncompleteError => e
      Util.error_exit(e)
    end

    private

    def connect_pg_server
      conn_options = {
        :dbname => options[:database],
        :host   => options[:pg_host],
        :port   => options[:port]
      }
      if options[:user]
        conn_options[:user] = options[:user]
      end
      if options[:password_file]
        conn_options[:password] = File.read(options[:password_file]).strip
      elsif ENV["PGPASSWORD"]
        conn_options[:password] = ENV["PGPASSWORD"]
      end
      PG::Connection.open(conn_options)
    rescue PG::Error => e
      Util.error_exit(e)
    end

    def rows_in_table(conn, table_name, order_by = nil)
      query = <<-SQL
SELECT *
FROM #{table_name}
#{"ORDER BY #{order_by}" if order_by}
SQL
      conn.exec_params(query)
    rescue PG::Error => e
      Util.error_exit(e)
    end

    def pg_rows_to_array(rows)
      result = []
      rows.each { |row| result << row }
      result
    end

    def filter_by_application_name(rows_array)
      if options[:only_miq_rows]
        rows_array = rows_array.select { |row| row["application_name"].start_with?('MIQ') }
      end

      rows_array.each do |row|
        next unless row["application_name"].end_with?('..')
        error_msg = "The application name for MIQ server/worker: #{row["application_name"]} is truncated"
        if options[:ignore_error]
          $stderr.puts error_msg
        else
          raise error_msg
        end
      end

      rows_array
    end

    def filter_by_database_name(rows_array)
      if options[:only_miq_rows]
        rows_array = rows_array.select { |row| row["datname"] == options[:database] }
      end
      rows_array
    end
  end
end
