#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)
require 'bundler/setup'
require 'trollop'

def find_group(group_name)
  group = MiqGroup.where(:description => group_name).first
  abort("MiqGroup  '#{group_name}' not found") if group.nil?
  group
end

def find_role(role_name)
  role = MiqUserRole.where(:name => role_name).first
  abort("MiqUserRole  '#{role_name}' not found") if role.nil?
  role
end

def duplicate_for_group(source_group_name, destination_group_name)
  destination_group = find_group(destination_group_name)
  destination_group.settings = find_group(source_group_name).settings
  destination_group.save!
  puts "Reports structure was succesfully cloned from '#{source_group_name}' to '#{destination_group_name}'"
rescue StandardError => e
  $stderr.puts e.message
end

def duplicate_for_role(source_group_name, destination_role_name)
  puts "Copying report structure from group '#{source_group_name}' to role ' #{destination_role_name}' ..."
  source_group = find_group(source_group_name)
  find_role(destination_role_name).miq_groups.each do |destination_group|
    begin
      destination_group.settings = source_group.settings
      destination_group.save!
      puts "  Reports structure was succesfully copied from '#{source_group_name}' to '#{destination_group.description}'"
    rescue StandardError => e
      $stderr.puts e.message
    end
  end
end

def reset_for_group(group_name)
  group = find_group(group_name)
  group.settings = nil
  group.save!
  puts "Succsefully removed custom report structure for group '#{group_name}'"
rescue StandardError => e
  $stderr.puts e.message
end

def reset_for_role(role_name)
  puts "Removing custom report structure for role '#{role_name}'..."
  find_role(role_name).miq_groups.each do |group|
    begin
      group.settings = nil
      group.save!
      puts "Succsefully removed custom report structure for group '#{group.description}'"
    rescue StandardError => e
      $stderr.puts e.message
    end
  end
end

opts = Trollop.options(ARGV) do
  banner "Utility to: \n" \
         "  - make report structure configured for a group available to another group\n" \
         "  - make report structure configured for a group available to role\n" \
         "  - reset report access to default for group or role\n" \
         "Example (Duplicate for Group): bundle exec ruby #{__FILE__} --source-group=EvmGroup --target-group=SomeGroup\n" \
         "Example (Duplicate for Role): bundle exec ruby #{__FILE__} --source-group=EvmGroup  --target-role=SomeRole\n" \
         "Example (Reset to Default for Group): bundle exec ruby #{__FILE__} --reset-group=SomeGroup\n" \
         "Example (Reset to Default for Role):  bundle exec ruby #{__FILE__} --reset-role=SomeRole\n"
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
  duplicate_for_group(opts[:source_group], opts[:target_group]) if opts[:target_group_given]
  duplicate_for_role(opts[:source_group], opts[:target_role]) if opts[:target_role_given]
else
  unless opts[:reset_group_given] || opts[:reset_role_given]
    abort("use either :reset_group or :reset_role parameter for resetting report structure to default")
  end
  reset_for_group(opts[:reset_group]) if opts[:reset_group_given]
  reset_for_role(opts[:reset_role]) if opts[:reset_role_given]
end