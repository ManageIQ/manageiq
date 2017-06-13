require 'rubygems'

# Set up gems listed in the Gemfile.
ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../../Gemfile', __FILE__)

require 'bundler/setup' if File.exist?(ENV['BUNDLE_GEMFILE'])
# add the lib dir of the engine if we are running as a dummy app for an engine
$LOAD_PATH.unshift File.expand_path('../../../lib', __dir__) if defined?(ENGINE_ROOT)

require 'bootsnap'

Bootsnap.setup(
  :cache_dir            => 'tmp/cache',
  :development_mode     => ENV['RAILS_ENV'] == 'development',
  :load_path_cache      => true,
  :autoload_paths_cache => true,
  :disable_trace        => false,
  :compile_cache_iseq   => true,
  :compile_cache_yaml   => true
)
