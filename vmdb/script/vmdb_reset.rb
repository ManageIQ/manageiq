# WARNING: DO NOT RUN THIS SCRIPT - EVER!!!
require 'rubygems'
require 'platform'
require 'fileutils'

$files_to_delete = %w(/etc/resolv.conf /etc/sysconfig/networking/profiles/default/resolv.conf /etc/resolv.conf.predhclient)

def stop_mongrel
  puts 'Stopping vmdb...'
  case Platform::IMPL
  when :linux
    if File.exist?('/etc/init.d/evmserverd')
      `/etc/init.d/evmserverd stop`
      i = 30
      while (i -= 1) > 0 && File.exist?("tmp/pids/evm.pid")
        sleep(1)
      end
    end
  when :mswin, :mingw
    `net stop evmappl`
  end
end

def reset_database()
  runner = case Platform::OS
  when :unix  then 'script/rails runner'
  when :win32 then 'ruby script/rails runner'
  end

  puts "Resetting database..."
  puts "Running [#{runner}] from [#{Dir.pwd}]"
  `#{runner} script/rake evm:db:reset --trace`
end

def clear_files()
  puts "Removing logs, guid, and misc. files"
  # Remove everything in the log folder
  Dir.glob(File.join(Dir.pwd, 'log', '*')).each {|f| FileUtils.rm_rf(f)}
  $files_to_delete << File.join(Dir.pwd, 'GUID')
  $files_to_delete.each {|f| File.delete(f) if File.exist?(f)}
end

begin
  # Check that we are being run correctly
  raise ArgumentError, "Run script with ruby directly.\n\n  Usage: ruby #{__FILE__}" unless __FILE__ == $0
  %w{app config db log script vendor}.each {|f| raise ArgumentError, "Run script from the root Rails directory." unless File.exist?(File.join(Dir.pwd, f))}

  puts 'Starting...'
  stop_mongrel
  reset_database
  clear_files
rescue ArgumentError
  puts $!
end
