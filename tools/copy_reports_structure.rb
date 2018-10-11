#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)

if __FILE__ == $PROGRAM_NAME
  $LOAD_PATH.push(File.expand_path(__dir__))
end

require 'trollop'
require 'copy_reports_structure/report_structure'

opts = Trollop.options(ARGV) do
  banner "Utility to: \n" \
         "  - make report structure configured for a group available to another group\n" \
         "  - make report structure configured for a group available to role\n" \
         "  - reset report access to default for group or role\n" \
         "Example (Duplicate for Group): bundle exec ruby #{__FILE__} --source-group=EvmGroup --target-group=SomeGroup\n" \
         "Example (Duplicate for Role): bundle exec ruby #{__FILE__} --source-group=EvmGroup  --target-role=SomeRole\n" \
         "Example (Reset to Default for Group): bundle exec ruby #{__FILE__} --reset-group=SomeGroup\n" \
         "Example (Reset to Default for Role):  bundle exec ruby #{__FILE__} --reset-role=SomeRole\n"
  opt :dry_run,  "Dry Run", :short => "d"
  opt :source_group, "Source group to take report structure from", :short => :none, :type => :string
  opt :target_group, "Target group to get report menue from source group", :short => :none, :type => :string
  opt :target_role, "Target role to get report menue from source group", :short => :none, :type => :string
  opt :reset_group, "Group to reset reports structure to default", :short => :none, :type => :string
  opt :reset_role, "Role to reset reports structure to default", :short => :none, :type => :string
end

if opts[:source_group_given]
  msg = ":source-group argument can not be used with :reset-group" if opts[:reset_group_given]
  msg ||= ":source-group argument can not be used with :reset-role" if opts[:reset_role_given]
  msg ||= "either :target-group or :target-role arguments requiered" unless opts[:target_group_given] || opts[:target_role_given]
  abort(msg) unless msg.nil?
  ReportStructure.duplicate_for_group(opts[:source_group], opts[:target_group], opts[:dry_run]) if opts[:target_group_given]
  ReportStructure.duplicate_for_role(opts[:source_group], opts[:target_role], opts[:dry_run]) if opts[:target_role_given]
else
  unless opts[:reset_group_given] || opts[:reset_role_given]
    abort("use either :reset_group or :reset_role parameter for resetting report structure to default")
  end
  ReportStructure.reset_for_group(opts[:reset_group], opts[:dry_run]) if opts[:reset_group_given]
  ReportStructure.reset_for_role(opts[:reset_role], opts[:dry_run]) if opts[:reset_role_given]
end

puts "**** Dry run, no updates have been made" if opts[:dry_run]