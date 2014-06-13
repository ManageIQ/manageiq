require 'rubygems'
require 'platform'
$:.push(File.join(File.dirname(__FILE__), "../util"))
require 'miq-system'

platform = Platform::IMPL
raise LoadError.new("VixDiskLib_raw not available for platform <#{platform}> (#{RUBY_PLATFORM})") unless [:linux, :mswin, :mingw].include?(platform)


base_so_dir = File.expand_path(File.join(File.dirname(__FILE__), "lib/#{MiqSystem.arch.to_s}-#{platform}"))
platform_ruby_dir = File.join(base_so_dir, "ruby#{RUBY_VERSION}")

#puts "base dir:     #{base_so_dir}"
#puts "platform dir: #{platform_ruby_dir}"
dir = File.exist?(platform_ruby_dir) ? platform_ruby_dir : base_so_dir

#puts "using directory: #{dir}"

version_load_order = %w{ 5.1 5.0 1.2 1.1 }

load_errors = []
version_load_order.each do |version|
  begin
    require File.join(dir, "VixDiskLib_raw.#{version}")
    break
  rescue LoadError => err
    load_errors << "VixDiskLib_raw: failed to load #{version} version with error: #{err.message}."
    next
  end
end

unless defined?(VixDiskLib_raw)
  STDERR.puts load_errors.join("\n")
  raise LoadError, "VixDiskLib_raw: failed to load any version!"
end
