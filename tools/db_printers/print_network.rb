#!/usr/bin/env ruby
require File.expand_path('../../config/environment', __dir__)

def print_switch(indent, switch)
  puts "#{indent}Switch: #{switch.name}"
  switch.lans.order(Arel.sql("lower(name)")).each do |lan|
    puts "#{indent}  Lan: #{lan.name}"
    vms = lan.guest_devices.collect { |gd| [gd.hardware.vm, gd.device_name] if gd.hardware && gd.hardware.vm }.compact
    vms.sort_by { |vm| vm[0].name.downcase }.each { |vm| puts "#{indent}    #{vm[0].class}: #{vm[0].name} (vNIC: #{vm[1]})" }
  end
end

Host.all.each do |host|
  puts "Host: #{host.name} [#{host.ipaddress}] (id: #{host.id})"

  found_switches = []
  unless host.hardware.nil?
    pnics = host.hardware.guest_devices.where(:device_type => 'ethernet').order(Arel.sql("lower(device_name)"))

    # Group the pNICs by Switch
    pnics_grouped = []
    pnics.each do |pnic|
      group = pnics_grouped.find { |pa| pa.find { |p| p.switch == pnic.switch } }
      if group.nil?
        group = []
        pnics_grouped << group
      end
      group << pnic
    end

    pnics_grouped.each do |pa|
      puts "  pNIC: #{pa.collect(&:device_name).join(", ")}"
      pnic = pa[0]
      unless pnic.switch.nil?
        print_switch("    ", pnic.switch)
        found_switches << pnic.switch.name
      end
    end
  end

  unless host.switches.length == found_switches.length
    puts "  pNIC: (None)"
    host.switches.order(Arel.sql("lower(name)")).each do |switch|
      next if found_switches.include?(switch.name)
      print_switch("    ", switch)
    end
  end

  puts("\n")
end
