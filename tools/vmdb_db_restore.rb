#!/usr/bin/env ruby

require 'optparse'

# Spinner Credit:
#
#   https://github.com/sindresorhus/cli-spinners/blob/8f4beecc/spinners.json#L894-L903
#
SPINNER = [ "∙∙∙", "●∙∙", "∙●∙", "∙∙●" ].freeze

@options = {
  :drop        => false,
  :environment => "development",
  :migrate     => false,
  :rails52     => false,
  :update      => true,
  :err_len     => 100
}

OptionParser.new do |opt|
  opt.banner = "Usage: #{File.basename $0} --db-name=DB_NAME [options] DB_DUMP"

  opt.separator ""
  opt.separator "Imports and prepares a MIQ database dump for a dev environment"
  opt.separator ""
  opt.separator "Assuming being run from the manageiq root directory"
  opt.separator ""
  opt.separator "Options"

  opt.on "-D", "--[no-]drop",                      "Drop Database? (default: no)" do |yes_no|
    @options[:drop] = yes_no
  end

  opt.on "-e", "--environment=RAILS_ENV", String,  "ENV['RAILS_ENV'] (default: development)" do |env|
    @options[:environment] = env
  end

  opt.on "-m", "--[no-]migrate",                   "Migrate? (default: no)" do |yes_no|
    @options[:migrate] = yes_no
  end

  opt.on "-n", "--db-name=DB_NAME",       String,  "New database name (required)" do |db_name|
    @options[:db_name] = db_name
  end

  opt.on "-r", "--region=REGION",         Integer, "Set ENV['REGION'] (def: NONE)" do |region|
    @options[:region] = region.to_s
  end

  opt.on       "--rails52",               String,  "Assume Rails v5.2" do
    @options[:rails52] = true
  end

  opt.on "-m", "--[no-]update",                    "bin/update? (default: yes)" do |yes_no|
    @options[:update] = yes_no
  end

  opt.on       "--[no-]verbose",                   "Verbose mode"  do |yes_no|
    @options[:verbose] = yes_no
  end
end.parse!

@db_dump_file = ARGV.shift
raise ArgumentError, "DB_DUMP is required!"             unless @db_dump_file

@db_name = @options[:db_name]
raise ArgumentError, "A new database name is required!" unless @db_name

require 'open3'
require 'io/console'


cmd_env = {}
cmd_env["RAILS_ENV"] = @options[:environment]
cmd_env["DB"]        = @options[:db_name]
cmd_env["REGION"]    = @options[:region]         if @options[:region]


# Interrupt without a stack trace
trap "INT" do puts; puts "Interrupt..."; exit 1 end


# :call-seq:
#   run_cmd(msg="Running command", cmd="command -a -b")
#   run_cmd(msg="Running command", cmd_env={"FOO" => "foo"}, cmd="command -a -b")
#
# Runs a command in a new process, and prints a message and spinner while it is
# running.
def run_cmd msg, env_or_cmd, cmd = nil, &block
  STDIN.echo = false
  cmd_env = cmd.nil? ? {} : env_or_cmd
  cmd     = env_or_cmd if cmd.nil?

  return if cmd.include?("migrate") && !@options[:migrate]

  outdata = []
  status  = nil
  spinner = 0
  verbose = " (#{cmd_env.inspect} #{cmd})" if @options[:verbose]
  print "\e[0;1;49m====> \e[1;32;49m#{msg}#{verbose}\e[0m    "

  Open3.popen2e cmd_env, cmd do |stdin, out, cmd_thr|
    # Spinner Thread
    spin = Thread.new do
      while cmd_thr.alive?
        spinner += 1
        print "\b\b\b#{SPINNER[spinner % 4]}"
        sleep 0.3
      end
      # cleanup stdout
      print "\b\b\b   ";
      puts
    end

    # Output thread
    #
    # Ensure output is being read, and store last N lines incase of error
    #
    output = Thread.new do
      new_line = nil
      while new_line = out.gets do
        outdata << new_line
        outdata.shift if outdata.size > @options[:err_len]
      end
    end

    # Input thread
    input = Thread.new do
      yield stdin
      stdin.close
    end if block_given?

    status = cmd_thr.value
    spin.join
    input.join if input
    output.join
  end

  unless cmd.include? "pg_restore"
    fail "Error:  #{cmd} did not complete sucessfully!\n\n#{outdata.join("")}" unless status.success?
  end
ensure
  STDIN.echo = true
end

def migrate_database
  cmd  = "bin/rake"
  cmd += " db:environment:set"  if @options[:rails52] && @options[:drop]
  cmd += " db:drop"             if @options[:drop]
  cmd += " db:create"
  cmd
end

def import_db
  if File.open(@db_dump_file, "rb") { |f| f.readpartial(5) } == "PGDMP"
    run_cmd "Dumping data into #{@db_name}",  %Q[pg_restore -v -U root -j 4 -d #{@db_name} "#{@db_dump_file}"]
  else
    stdin_proc = Proc.new do |stdin|
      require 'zlib'

      io = File.open(@db_dump_file)

      # try zlib
      begin
        io = Zlib::GzipReader.new(io)
      rescue Zlib::GzipFile::Error
      end

      skip_count = 0
      connect_line_regxp = /^\\connect [^\s]+/

      # check the first 1000 lines to find any `\connect DBNAME` lines.  Keep
      # track of the most recent one.
      io.each_line.with_index do |line, index|
        skip_count = index if line.match connect_line_regxp
        break if index > 1000
      end

      # start from the beginning again, incase we skipped nothing
      io.rewind

      # don't pass anything before the `skip_count` to psql, and after that,
      # forward all of the lines on to `psql`
      io.each_line.with_index do |line, index|
        index <= skip_count ? next : stdin.puts(line)
      end
    end
    run_cmd "Dumping data into #{@db_name}", {}, %Q[psql -U root -d #{@db_name}], &stdin_proc
  end
end

run_cmd "Bundle update",                 %Q[bin/bundle update]
run_cmd "Creating database",    cmd_env, migrate_database
import_db
run_cmd "Migrating database",   cmd_env, %Q[bin/rake db:migrate]
run_cmd "Fixing database auth",          %Q[bundle exec tools/fix_auth.rb --v2 --invalid bogus --db #{@db_name}]
run_cmd "Update dependencies",  cmd_env, %Q[bin/update]
run_cmd "Update default auth",  cmd_env, %Q[bin/rails runner 'User.where(:userid => "admin").each {|u| u.update_attribute :password, "smartvm"}']
