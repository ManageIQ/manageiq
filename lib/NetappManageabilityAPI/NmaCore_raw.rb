require 'rubygems'
require 'platform'
$:.push(File.join(File.dirname(__FILE__), "../util"))
require 'miq-system'

platform = Platform::IMPL

base_so_dir = File.expand_path(File.join(File.dirname(__FILE__), "NmaCore/lib/#{MiqSystem.arch.to_s}-#{platform}"))
platform_ruby_dir = File.join(base_so_dir, "ruby#{RUBY_VERSION}")

dir = File.exist?(platform_ruby_dir) ? platform_ruby_dir : base_so_dir

require File.join(dir, "NmaCore_raw")