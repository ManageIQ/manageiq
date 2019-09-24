#!/usr/bin/env ruby

# usage: pg_inspector operation [options]
# use pg_inspector -h to see full help.

if __FILE__ == $PROGRAM_NAME
  $LOAD_PATH.push(File.expand_path(__dir__))
  $LOAD_PATH.push(File.expand_path(File.join(__dir__, %w(.. lib))))
end

require 'pg_inspector/util'
require 'pg_inspector/cli'

if __FILE__ == $PROGRAM_NAME
  trap("INT") { PgInspector::Util.error_msg_exit("Operation abort") }
  PgInspector::Cli.run(ARGV)
end
