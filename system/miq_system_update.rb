#!/usr/bin/env ruby

puts "Setting Variables"
PREFIX = "MIQ System Update ---"
BACKUP_DESTINATION = '/root/evmbackups/'
SYSTEM_LINKS = File.join("/var/www/miq/system/LINK/**","{*,.*}")
SYSTEM_COPY = File.join("/var/www/miq/system/COPY/**","{*,.*}")

puts "#{PREFIX} Requiring Gems"
require 'fileutils'
require 'yaml'


puts "#{PREFIX} Creating Backup Destination"
FileUtils.mkdir_p(BACKUP_DESTINATION)


# LINK the files in the LINK directory
puts "#{PREFIX} Linking Files"
Dir.glob(SYSTEM_LINKS).each do |file|
  system_location = file.split("/var/www/miq/system/LINK").last
  file_name = File.basename(system_location)

  next if File.directory?(file)

  if file =~ /\/system\/.+\/etc\//
    File.chmod(0755, file)
  end

  if File.file?(system_location) && !File.symlink?(system_location)
    dest_name = [file_name,Time.now.utc.strftime("%Y%m%d_%H%M%S%Z")].join("-")
    dest = File.join(BACKUP_DESTINATION, dest_name)
    FileUtils.mv(system_location, dest)
    raise "#{PREFIX} File #{system_location} can't be moved." if File.exists?(system_location)
    puts "#{PREFIX} Backed up existing file to #{BACKUP_DESTINATION}."
  end

  FileUtils.symlink(file, system_location, :force => true)

  if File.dirname(system_location) == "/etc/init.d"
    `chkconfig --del #{file_name}`
    `chkconfig --add #{file_name}`
  end
  puts "#{PREFIX} Linked System file #{file_name}."
end


#Copy files that can't be linked
puts "#{PREFIX} Copying Files"
Dir.glob(SYSTEM_COPY).each do |file|
  system_location = file.split("/var/www/miq/system/COPY").last
  file_name = File.basename(system_location)

  next if File.directory?(file)

  if file =~ /\/system\/.+\/etc\//
    File.chmod(0644, file)
  end

  if File.exists?(system_location)
    dest_name = [file_name,Time.now.utc.strftime("%Y%m%d_%H%M%S%Z")].join("-")
    dest = File.join(BACKUP_DESTINATION, dest_name)
    FileUtils.mv(system_location, dest)
    raise "#{PREFIX} File #{system_location} can't be moved." if File.exists?(system_location)
    puts "#{PREFIX} Backed up existing file to #{BACKUP_DESTINATION}."
  end

  FileUtils.install(file, system_location)

  if File.dirname(system_location) == "/etc/init.d"
    `chkconfig --del #{file_name}`
    `chkconfig --add #{file_name}`
  end
  puts "#{PREFIX} Copied System file #{file_name}."
end


#Cleanup other files on the appliance that are no longer used
puts "#{PREFIX} Cleaning up Files"
cleanup = YAML.load_file('/var/www/miq/system/cleanup.yml')
cleanup.each do |file|
  file_name = File.basename(file)
  if File.symlink?(file)
    FileUtils.rm(file)
    raise "#{PREFIX} Symlink #{file} wasn't removed." if File.exists?(file)
    puts "#{PREFIX} Removed Symlink #{file}."
  end

  if File.file?(file) || File.directory?(file)
    dest_name = [file_name,Time.now.utc.strftime("%Y%m%d_%H%M%S%Z")].join("-")
    dest = File.join(BACKUP_DESTINATION, dest_name)
    FileUtils.mv(file, dest)
    raise "#{PREFIX} File #{file} can't be moved." if File.exists?(file)
    puts "#{PREFIX} Backed up existing file to #{dest}."
  end
end

puts "#{PREFIX} Update Complete"
