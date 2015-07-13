rails_root = defined?(Rails) ? Rails.root : File.join(File.dirname(__FILE__), "../")
SCRIPT  = File.join(File.dirname(__FILE__), "run_rake.rb")
RUNNER  = "#{File.join(rails_root, "bin/rails")} runner"
DB_FILE = File.join(rails_root, "data/db_settings")

require 'rubygems'
require 'bundler/setup'

$:.unshift(File.dirname(__FILE__))
require 'miq_std_io'
require 'erb'
require 'base64'

require 'active_record'
require 'active_record/errors'

def run_rake(arg)
  rv = `#{RUNNER} #{SCRIPT} #{arg} 2>&1`
  if $? != 0
    raise MiqRunRakeError, "#{rv}"
  end
end

class MiqRunRakeError < StandardError; end

MiqStdIo.std_io_to_files do
  begin
    f_data = File.open(DB_FILE, "rb") {|f| f.read}
    $db_settings = Marshal.load(Base64.decode64(f_data.split("\n").join))
    from_save = $db_settings.delete(:from_save)

    # force any connection errors to be raised immediately instead of retrying
    require "active_record/connection_adapters/postgresql_adapter"
    ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.auto_connect = false

    $conn = ActiveRecord::Base.establish_connection($db_settings).connection

    tables = $conn.tables
    unless tables
      $stderr.write("Unable to retrieve tables\n", true)
      exit 1
    end

    # When DB settings are saved, rake an empty DB or check for pending migrations for non-empty DB, and run simple query for schema info
    if from_save
      $conn.disconnect!
      if tables.empty?
        run_rake("db:migrate")
      else
        run_rake("db:abort_if_pending_migrations")
      end
      $conn = ActiveRecord::Base.establish_connection($db_settings).connection if $conn.nil? || !$conn.active?
      migrations = $conn.select_all("select * from schema_migrations")
      unless migrations
        $stderr.write("Unable to retrieve schema information\n", true)
        exit 1
      end
    end
  rescue MiqRunRakeError
    # Don't write to $stderr since the method run_rake will write the error to $stderr
    exit 1
  rescue Exception => err
    $stderr.write("#{err.message}\n", true)
    exit 1
  end
  $stdout.write("Database connection successful\n")
  exit 0
end
