raise "Ruby versions less than 2.3.1 are unsupported!" if RUBY_VERSION < "2.3.1"

source 'https://rubygems.org'

#
# VMDB specific gems
#

gem "manageiq-gems-pending", ">0", :require => 'manageiq-gems-pending', :git => "https://github.com/ManageIQ/manageiq-gems-pending.git", :branch => "master"
# Modified gems for gems-pending.  Setting sources here since they are git references
gem "handsoap", "~>0.2.5", :require => false, :git => "https://github.com/ManageIQ/handsoap.git", :tag => "v0.2.5-5"

# when using this Gemfile inside a providers Gemfile, the dependency for the provider is already declared
def manageiq_plugin(plugin_name)
  unless dependencies.detect { |d| d.name == plugin_name }
    gem plugin_name, :git => "https://github.com/ManageIQ/#{plugin_name}", :branch => "master"
  end
end

manageiq_plugin "manageiq-providers-ansible_tower" # can't move this down yet, because we can't autoload ManageIQ::Providers::AnsibleTower::Shared
manageiq_plugin "manageiq-schema"

# Unmodified gems
gem "activerecord-id_regions",        "~>0.2.0"
gem "activerecord-session_store",     "~>1.1"
gem "acts_as_tree",                   "~>2.7" # acts_as_tree needs to be required so that it loads before ancestry
gem "ancestry",                       "~>3.0.4",       :require => false
gem "bcrypt",                         "~> 3.1.10",     :require => false
gem "bundler",                        ">=1.11.1",      :require => false
gem "color",                          "~>1.8"
gem "config",                         "~>1.6.0",       :require => false
gem "dalli",                          "=2.7.6",        :require => false
gem "default_value_for",              "~>3.0.3"
gem "docker-api",                     "~>1.33.6",      :require => false
gem "elif",                           "=0.1.0",        :require => false
gem "fast_gettext",                   "~>1.2.0"
gem "gettext_i18n_rails",             "~>1.7.2"
gem "gettext_i18n_rails_js",          "~>1.3.0"
gem "hamlit",                         "~>2.8.5"
gem "highline",                       "~>1.6.21",      :require => false
gem "inifile",                        "~>3.0",         :require => false
gem "inventory_refresh",              "~>0.1.1",       :require => false
gem "kubeclient",                     "~>2.4",         :require => false # For scaling pods at runtime
gem "linux_admin",                    "~>1.2.1",       :require => false
gem "log_decorator",                  "~>0.1",         :require => false
gem "manageiq-api-client",            "~>0.3.2",       :require => false
gem "manageiq-messaging",                              :require => false, :git => "https://github.com/ManageIQ/manageiq-messaging", :branch => "master"
gem "manageiq-postgres_ha_admin",     "~>3.0",         :require => false
gem "memoist",                        "~>0.15.0",      :require => false
gem "mime-types",                     "~>3.0",         :path => File.expand_path("mime-types-redirector", __dir__)
gem "more_core_extensions",           "~>3.5"
gem "nakayoshi_fork",                 "~>0.0.3"  # provides a more CoW friendly fork (GC a few times before fork)
gem "net-ldap",                       "~>0.16.1",      :require => false
gem "net-ping",                       "~>1.7.4",       :require => false
gem "openscap",                       "~>0.4.8",       :require => false
gem "pg",                             "~>0.18.2",      :require => false
gem "pg-dsn_parser",                  "~>0.1.0",       :require => false
gem "query_relation",                 "~>0.1.0",       :require => false
gem "rails",                          "~>5.0.6"
gem "rails-i18n",                     "~>5.x"
gem "rake",                           ">=11.0",        :require => false
gem "rest-client",                    "~>2.0.0",       :require => false
gem "ripper_ruby_parser",             "~>1.2.0",       :require => false
gem "ruby-progressbar",               "~>1.7.0",       :require => false
gem "rubyzip",                        "~>1.2.2",       :require => false
gem "rugged",                         "~>0.27.0",      :require => false
gem "simple-rss",                     "~>1.3.1",       :require => false
gem "snmp",                           "~>1.2.0",       :require => false
gem "sqlite3",                                         :require => false
gem "trollop",                        "~>2.1.3",       :require => false

# Modified gems (forked on Github)
gem "ruport",                         "=1.7.0",                       :git => "https://github.com/ManageIQ/ruport.git", :tag => "v1.7.0-3"

# In 1.9.3: Time.parse uses british version dd/mm/yyyy instead of american version mm/dd/yyyy
# american_date fixes this to be compatible with 1.8.7 until all callers can be converted to the 1.9.3 format prior to parsing.
# See miq_expression_spec Date/Time Support examples.
# https://github.com/jeremyevans/ruby-american_date
gem "american_date"

# Make sure to tag your new bundler group with the manageiq_default group in addition to your specific bundler group name.
# This default is used to automatically require all of our gems in processes that don't specify which bundler groups they want.
#
### providers
group :amazon, :manageiq_default do
  manageiq_plugin "manageiq-providers-amazon"
  gem "amazon_ssa_support",                          :require => false, :git => "https://github.com/ManageIQ/amazon_ssa_support.git", :branch => "master" # Temporary dependency to be moved to manageiq-providers-amazon when officially release
end

group :azure, :manageiq_default do
  manageiq_plugin "manageiq-providers-azure"
end

group :foreman, :manageiq_default do
  manageiq_plugin "manageiq-providers-foreman"
  gem "foreman_api_client",             ">=0.1.0",   :require => false, :git => "https://github.com/ManageIQ/foreman_api_client.git", :branch => "master"
end

group :google, :manageiq_default do
  manageiq_plugin "manageiq-providers-google"
end

group :kubernetes, :openshift, :manageiq_default do
  manageiq_plugin "manageiq-providers-kubernetes"
end

group :kubevirt, :manageiq_default do
  manageiq_plugin "manageiq-providers-kubevirt"
end

group :lenovo, :manageiq_default do
  manageiq_plugin "manageiq-providers-lenovo"
end

group :nuage, :manageiq_default do
  manageiq_plugin "manageiq-providers-nuage"
end

group :redfish, :manageiq_default do
  manageiq_plugin "manageiq-providers-redfish"
end

group :qpid_proton, :optional => true do
  gem "qpid_proton",                    "~>0.22.0",      :require => false
end

group :openshift, :manageiq_default do
  manageiq_plugin "manageiq-providers-openshift"
  gem "htauth",                         "2.0.0",         :require => false # used by container deployment
end

group :openstack, :manageiq_default do
  manageiq_plugin "manageiq-providers-openstack"
end

group :ovirt, :manageiq_default do
  manageiq_plugin "manageiq-providers-ovirt"
  gem "ovirt_metrics",                  "~>2.0.0",       :require => false
end

group :scvmm, :manageiq_default do
  manageiq_plugin "manageiq-providers-scvmm"
end

group :vmware, :manageiq_default do
  manageiq_plugin "manageiq-providers-vmware"
  gem "vmware_web_service",             "~>0.3.0"
end

### shared dependencies
group :google, :openshift, :manageiq_default do
  gem "sshkey",                         "~>1.8.0",       :require => false
end

group :automate, :cockpit, :manageiq_default do
  gem "open4",                          "~>1.3.0",       :require => false
end

### end of provider bundler groups

group :automate, :seed, :manageiq_default do
  manageiq_plugin "manageiq-automation_engine"
end

group :replication, :manageiq_default do
  gem "pg-pglogical",                   "~>2.1.2",       :require => false
end

group :rest_api, :manageiq_default do
  manageiq_plugin "manageiq-api"
end

group :graphql_api, :manageiq_default do
  manageiq_plugin "manageiq-graphql"
end

group :scheduler, :manageiq_default do
  # Modified gems (forked on Github)
  gem "rufus-scheduler", "=3.1.10.2", :git => "https://github.com/ManageIQ/rufus-scheduler.git", :require => false, :tag => "v3.1.10-2"
end

group :seed, :manageiq_default do
  manageiq_plugin "manageiq-content"
end

group :smartstate, :manageiq_default do
  gem "manageiq-smartstate",            "~>0.2.14",       :require => false
end

group :consumption, :manageiq_default do
  manageiq_plugin "manageiq-consumption"
  gem 'hashdiff'
end

group :ui_dependencies do # Added to Bundler.require in config/application.rb
  manageiq_plugin "manageiq-ui-classic"
  # Modified gems (forked on Github)
  gem "jquery-rjs",                   "=0.1.1",                       :git => "https://github.com/ManageIQ/jquery-rjs.git", :tag => "v0.1.1-1"
end

group :v2v, :ui_dependencies do
  manageiq_plugin "manageiq-v2v"
end

group :web_server, :manageiq_default do
  gem "puma",                           "~>3.7.0"
  gem "responders",                     "~>2.0"
  gem "ruby-dbus" # For external auth
  gem "secure_headers",                 "~>3.0.0"
end

group :web_socket, :manageiq_default do
  gem "websocket-driver",               "~>0.6.3"
end

### Start of gems excluded from the appliances.
# The gems listed below do not need to be packaged until we find it necessary or useful.
# Only add gems here that we do not need on an appliance.
#
unless ENV["APPLIANCE"]
  group :development do
    gem "foreman"
    gem "haml_lint",        "~>0.20.0", :require => false
    gem "rubocop",          "~>0.52.1", :require => false
    # ruby_parser is required for i18n string extraction
    gem "ruby_parser",                  :require => false
    gem "scss_lint",        "~>0.48.0", :require => false
    gem "yard"
  end

  group :test do
    gem "brakeman",         "~>3.3",    :require => false
    gem "capybara",         "~>2.5.0",  :require => false
    gem "coveralls",                    :require => false
    gem "factory_girl",     "~>4.5.0",  :require => false
    gem "timecop",          "~>0.7.3",  :require => false
    gem "vcr",              "~>3.0.2",  :require => false
    gem "webmock",          "~>2.3.1",  :require => false
  end

  group :development, :test do
    gem "parallel_tests"
    gem "rspec-rails",      "~>3.6.0"
  end
end

#
# Custom Gemfile modifications
#
# To develop a gem locally and override its source to a checked out repo
#   you can use this helper method in Gemfile.dev.rb e.g.
#
# override_gem 'manageiq-ui-classic', :path => "../manageiq-ui-classic"
#
def override_gem(name, *args)
  if dependencies.any?
    raise "Trying to override unknown gem #{name}" unless (dependency = dependencies.find { |d| d.name == name })
    dependencies.delete(dependency)

    calling_file = caller_locations.detect { |loc| !loc.path.include?("lib/bundler") }.path
    calling_dir  = File.dirname(calling_file)

    args.last[:path] = File.expand_path(args.last[:path], calling_dir) if args.last.kind_of?(Hash) && args.last[:path]
    gem(name, *args).tap do
      warn "** override_gem: #{name}, #{args.inspect}, caller: #{calling_file}" unless ENV["RAILS_ENV"] == "production"
    end
  end
end

# Load other additional Gemfiles
#   Developers can create a file ending in .rb under bundler.d/ to specify additional development dependencies
Dir.glob(File.join(__dir__, 'bundler.d/*.rb')).each { |f| eval_gemfile(File.expand_path(f, __dir__)) }
