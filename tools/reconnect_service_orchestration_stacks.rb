#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)
require "optimist"

opts = Optimist.options do
  opt :dry_run, "Just print out what would be done without modifying anything", :type => :boolean, :default => true
end

if opts[:dry_run]
  puts "**** This is a dry-run, nothing will be updated! ****"
else
  puts "**** THIS WILL MODIFY YOUR SERVICE ORCHESTRATION STACKS ****"
  puts "     Press Enter to Continue: "
  STDIN.getc
end

puts "Starting ServiceOrchestration reconnection.."
puts

reconnected = 0

ServiceOrchestration.all.each do |service|
  puts "Checking service #{service.id} #{service.name}.."

  service.orchestration_stacks.each do |orchestration_stack|
    if orchestration_stack
      puts " Existing OrchestrationStack #{orchestration_stack.id} #{orchestration_stack.name} #{orchestration_stack.ems_ref}, OK"
    else
      puts " Invalid OrchestrationStack, trying to repair.."
      puts "  Searching Stack's ems_ref in options.."
      stack_ems_id = service.options[:orchestration_stack]["ems_id"]
      stack_ems_ref = service.options[:orchestration_stack]["ems_ref"]

      if stack_ems_id && stack_ems_ref
        puts "  Stack ems_id and ems_ref found #{stack_ems_id} #{stack_ems_ref}, searching to a matching OrchestrationStack.."
        matching_stack = OrchestrationStack.find_by(:ems_id => stack_ems_id, :ems_ref => stack_ems_ref)
        if matching_stack
          puts "  OrchestrationStack found id:#{matching_stack.id}, reconnecting.."
          if opts[:dry_run]
            puts "  **** This is a dry-run, nothing updated, skipping. ****"
          else
            service.add_resource!(matching_stack)
            reconnected += 1
          end
        else
          puts "  Not found, skipping.."
        end
      else
        puts " Cannot find stack ems_id or ems_ref key in service options, skipping.."
      end
    end
    puts
  end
end

puts "ServiceOrchestration reconnection has finished, #{reconnected} records reconnected."
