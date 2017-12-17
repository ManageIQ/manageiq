#!/usr/bin/env ruby
require File.expand_path('../config/environment', __dir__)

def header
  output  = "Name\tOwner\tOwner Userid\tOwning Group\tRetired?\tRetirement Date\tRetirement Warning"
  output += "\n"
  output += "====\t=====\t============\t============\t========\t===============\t=================="
  output
end

def vm_details(vm)
  "#{vm.name}\t#{vm.evm_owner_name}\t#{vm.evm_owner_userid}\t#{vm.owning_ldap_group}\t#{vm.retired?}\t#{vm.retires_on}\t#{vm.retirement_warn}"
end

def list
  puts header
  Vm.all.each { |vm| puts vm_details(vm) }
end

def get_invalid(valid_warnings)
  valid_warnings ||= []
  valid_warnings = Array.new(valid_warnings) unless valid_warnings.kind_of?(Array)

  if valid_warnings.empty?
    puts "Valid Warnings not specified"
    return []
  end

  Vm.all.select { |vm| vm.evm_owner && !valid_warnings.include?(vm.retirement_warn) }
end

def list_invalid(valid_warnings)
  invalid_vms = get_invalid(valid_warnings)

  return if invalid_vms.empty?

  puts header
  invalid_vms.each { |vm| puts vm_details(vm) }
end

def reset_invalid(valid_warnings, reset_warning)
  invalid_vms = get_invalid(valid_warnings)

  return if invalid_vms.empty?

  puts header
  invalid_vms.each do |vm|
    old_warning = vm.retirement_warn
    vm.retirement_warn = reset_warning
    vm.save!
    puts "#{vm.name}\t#{vm.evm_owner_name}\t#{vm.evm_owner_userid}\t#{vm.owning_ldap_group}\t#{vm.retired?}\t#{vm.retires_on}\t#{old_warning} => #{vm.retirement_warn}"
  end
end

def parse_command_line_option(arg)
  if arg.include?('=')
    opt, value = arg.split('=')
  else
    raise "No Value Provided for Command Line Option: #{arg.inspect}" unless $ARGV.length > 0
    opt  = arg
    value = $ARGV.shift
  end
  return opt, value
end

def parse_command_line
  cmdline_parms = {}
  original = $ARGV.dup
  if $ARGV.length > 0
    while $ARGV.length > 0
      break unless $ARGV.first.starts_with?("-")
      break if     $ARGV.first == '--'

      opt, value = parse_command_line_option($ARGV.shift)

      case opt.downcase
      when "--valid_warnings"
        cmdline_parms[:valid_warnings]  = value.split(',').collect { |v| v.strip.to_i }
      when "--default_warnings"
        cmdline_parms[:default_warning] = value.to_i
      else
        raise "Invalid Command Line Option: #{opt.inspect}"
      end
    end

    cmdline_parms[:verb] = $ARGV.shift                 if $ARGV.length > 0
    raise "Invalid Command Line: #{original.inspect}"  if $ARGV.length > 0
  end

  #  puts "Command Line Parsed: #{cmdline_parms.inspect}"
  cmdline_parms
end

DEFAULTS = {
  :verb            => "list",
  :valid_warnings  => [2, 7],
  :default_warning => 7,
}

parameters = DEFAULTS.merge(parse_command_line)

case parameters[:verb].downcase
when "list"
  list
when "list_invalid"
  list_invalid(parameters[:valid_warnings])
when "reset_invalid"
  reset_invalid(parameters[:valid_warnings], parameters[:default_warning])
else
  puts "Invalid Verb on Command Line: <#{parameters[:verb]}>"
end
