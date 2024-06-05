raise "Ruby versions < 3.0.1 are unsupported!"  if RUBY_VERSION < "3.0.1"
raise "Ruby versions >= 3.2.0 are unsupported!" if RUBY_VERSION >= "3.2.0"

source 'https://rubygems.org'

plugin "bundler-inject", "~> 2.0"
require File.join(Bundler::Plugin.index.load_paths("bundler-inject")[0], "bundler-inject") rescue nil

#
# VMDB specific gems
#
gem "manageiq-gems-pending", ">0", :git => "https://github.com/ManageIQ/manageiq-gems-pending.git", :branch => "master"

# when using this Gemfile inside a providers Gemfile, the dependency for the provider is already declared
def manageiq_plugin(plugin_name)
  unless dependencies.detect { |d| d.name == plugin_name }
    gem plugin_name, :git => "https://github.com/ManageIQ/#{plugin_name}", :branch => "master"
  end
end

manageiq_plugin "manageiq-schema"

# Unmodified gems
gem "activerecord-session_store",       "~>2.0"
gem "activerecord-virtual_attributes",  "~>6.1.2"
gem "acts_as_tree",                     "~>2.7" # acts_as_tree needs to be required so that it loads before ancestry
gem "ancestry",                         "~>4.1.0",           :require => false
gem "awesome_spawn",                    "~>1.6",             :require => false
gem "aws-sdk-s3",                       "~>1.0",             :require => false # For FileDepotS3
gem "bcrypt",                           "~> 3.1.10",         :require => false
gem "bootsnap",                         ">= 1.8.1",          :require => false # for psych 3.3.2+ / 4 unsafe_load
gem "bundler",                          "~> 2.2", ">= 2.2.15", *("!= 2.5.0".."!= 2.5.9"), :require => false
gem "byebug",                                                :require => false
gem "color",                            "~>1.8"
gem "config",                           "~>2.2", ">=2.2.3",  :require => false
gem "connection_pool",                                       :require => false # For Dalli
gem "dalli",                            "~>3.2.3",           :require => false
gem "default_value_for",                "~>3.3"
gem "docker-api",                       "~>1.33.6",          :require => false
gem "elif",                             "=0.1.0",            :require => false
gem "fast_gettext",                     "~>2.0.1"
gem "ffi",                              "< 1.17.0",          :require => false
gem "gettext_i18n_rails",               "~>1.11"
gem "gettext_i18n_rails_js",            "~>1.3.0"
gem "hamlit",                           "~>2.11.0"
gem "inifile",                          "~>3.0",             :require => false
gem "inventory_refresh",                "~>2.1",             :require => false
gem "kubeclient",                       "~>4.0",             :require => false # For scaling pods at runtime
gem "linux_admin",                      "~>3.0",             :require => false
gem "listen",                           "~>3.2",             :require => false
gem "manageiq-api-client",              "~>0.3.6",           :require => false
gem "manageiq-loggers",                 "~>1.0", ">=1.1.1",  :require => false
gem "manageiq-messaging",               "~>1.0", ">=1.4.3",  :require => false
gem "manageiq-password",                "~>1.0",             :require => false
gem "manageiq-postgres_ha_admin",       "~>3.2",             :require => false
gem "manageiq-ssh-util",                "~>0.2.0",           :require => false
gem "memoist",                          "~>0.16.0",          :require => false
gem "money",                            "~>6.13.5",          :require => false
gem "more_core_extensions"                                                     # min version should be set in manageiq-gems-pending, not here
gem "net-ftp",                          "~>0.1.2",           :require => false
gem "net-ldap",                         "~>0.16.1",          :require => false
gem "net-ping",                         "~>1.7.4",           :require => false
gem "openscap",                         "~>0.4.8",           :require => false
gem "optimist",                         "~>3.0",             :require => false
gem "pg",                               ">=1.4.1",           :require => false
gem "pg-dsn_parser",                    "~>0.1.1",           :require => false
gem "prism",                            ">=0.25.0",          :require => false # Used by DescendantLoader
gem "psych",                            ">=3.1",             :require => false # 3.1 safe_load changed positional to kwargs like aliases: true: https://github.com/ruby/psych/commit/4d4439d6d0adfcbd211ea295779315f1baa7dadd
gem "query_relation",                   "~>0.1.0",           :require => false
gem "rack",                             ">=2.2.6.4",         :require => false
gem "rack-attack",                      "~>6.5.0",           :require => false
gem "rails",                            "~>6.1.7", ">=6.1.7.8"
gem "rails-i18n",                       "~>6.x"
gem "rake",                             ">=12.3.3",          :require => false
gem "rest-client",                      "~>2.1.0",           :require => false
gem "ruby_parser",                                           :require => false # Required for i18n string extraction, and DescentdantLoader (via prism)
gem "ruby-progressbar",                 "~>1.7.0",           :require => false
gem "rubyzip",                          "~>2.0.0",           :require => false
gem "rugged",                           "~>1.5.0",           :require => false
gem "ruport",                           "~>1.8.0"
gem "snmp",                             "~>1.2.0",           :require => false
gem "sprockets",                        "~>3.7.2",           :require => false
gem "sync",                             "~>0.5",             :require => false
gem "sys-filesystem",                   "~>1.4.3"
gem "terminal",                                              :require => false
gem "wim_parser",                       "~>1.0",             :require => false

# gems to resolve security issues
# CVE-2021-33621 fixed: ruby 3.1.4 - https://github.com/advisories/GHSA-vc47-6rqg-c7f5
gem "cgi",  "~> 0.3.5"
# CVE-2023-28756 fixed: ruby 3.1.4 - https://github.com/advisories/GHSA-fg7x-g82r-94qc
gem "time", "~> 0.2.2"
# CVE-2023-36617 https://github.com/advisories/GHSA-hww2-5g85-429m
gem "uri",  ">= 0.12.2"

# Custom gem that replaces mime-types in order to redirect mime-types calls to mini_mime
#   Source is located at https://github.com/ManageIQ/mime-types-redirector
gem "mime-types",                       "~>3.0",             :require => false, :source => "https://rubygems.manageiq.org"

# Modified gems (forked on Github)
gem "handsoap",                         "=0.2.5.5",          :require => false, :source => "https://rubygems.manageiq.org" # for manageiq-gems-pending only

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
  gem "amazon_ssa_support",                                  :require => false, :git => "https://github.com/ManageIQ/amazon_ssa_support.git", :branch => "master" # Temporary dependency to be moved to manageiq-providers-amazon when officially release
end

group :ansible_tower, :manageiq_default do
  manageiq_plugin "manageiq-providers-ansible_tower"
end

group :autosde, :manageiq_default do
  manageiq_plugin "manageiq-providers-autosde"
end

group :awx, :manageiq_default do
  manageiq_plugin "manageiq-providers-awx"
end

group :azure, :manageiq_default do
  manageiq_plugin "manageiq-providers-azure"
end

group :azure_stack, :manageiq_default do
  manageiq_plugin "manageiq-providers-azure_stack"
end

group :cisco_intersight, :manageiq_default do
  manageiq_plugin "manageiq-providers-cisco_intersight"
end

group :embedded_terraform, :manageiq_default do
  manageiq_plugin "manageiq-providers-embedded_terraform"
end

group :foreman, :manageiq_default do
  manageiq_plugin "manageiq-providers-foreman"
end

group :google, :manageiq_default do
  manageiq_plugin "manageiq-providers-google"
end

group :ibm_cic, :manageiq_default do
  manageiq_plugin "manageiq-providers-ibm_cic"
end

group :ibm_cloud, :manageiq_default do
  manageiq_plugin "manageiq-providers-ibm_cloud"
end

group :ibm_power_hmc, :manageiq_default do
  manageiq_plugin "manageiq-providers-ibm_power_hmc"
end

group :ibm_power_vc, :manageiq_default do
  manageiq_plugin "manageiq-providers-ibm_power_vc"
end

group :ibm_terraform, :manageiq_default do
  manageiq_plugin "manageiq-providers-ibm_terraform"
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

group :nsxt, :manageiq_default do
  manageiq_plugin "manageiq-providers-nsxt"
end

group :nuage, :manageiq_default do
  manageiq_plugin "manageiq-providers-nuage"
end

group :oracle_cloud, :manageiq_default do
  manageiq_plugin "manageiq-providers-oracle_cloud"
end

group :redfish, :manageiq_default do
  manageiq_plugin "manageiq-providers-redfish"
end

group :red_hat_virtualization, :manageiq_default do
  manageiq_plugin "manageiq-providers-red_hat_virtualization"
end

group :qpid_proton, :optional => true do
  gem "qpid_proton",                    "~>0.37.0",          :require => false
end

group :systemd, :optional => true do
  gem "dbus-systemd",                   "~>1.1.0",           :require => false
  gem "sd_notify",                      "~>0.1.0",           :require => false
  gem "systemd-journal",                "~>1.4.2",           :require => false
end

group :openshift, :manageiq_default do
  manageiq_plugin "manageiq-providers-openshift"
end

group :openstack, :manageiq_default do
  manageiq_plugin "manageiq-providers-openstack"
end

group :ovirt, :manageiq_default do
  manageiq_plugin "manageiq-providers-ovirt"
end

group :vmware, :manageiq_default do
  manageiq_plugin "manageiq-providers-vmware"
end

group :workflows, :manageiq_default do
  manageiq_plugin "manageiq-providers-workflows"
end

### shared dependencies
group :google, :openshift, :manageiq_default do
  gem "sshkey",                         "~>1.8.0",           :require => false
end

### end of provider bundler groups

group :automate, :seed, :manageiq_default do
  manageiq_plugin "manageiq-automation_engine"
end

group :replication, :manageiq_default do
  gem "pg-logical_replication",         "~>1.2",             :require => false
end

group :rest_api, :manageiq_default do
  manageiq_plugin "manageiq-api"
end

group :scheduler, :manageiq_default do
  gem "rufus-scheduler"
end
# rufus has et-orbi dependency, v1.2.2 has patch for ConvertTimeToEoTime that we need
gem "et-orbi",                          ">= 1.2.2"

group :seed, :manageiq_default do
  manageiq_plugin "manageiq-content"
end

group :smartstate, :manageiq_default do
  gem "manageiq-smartstate",            "~>0.9.0",           :require => false
end

group :consumption, :manageiq_default do
  manageiq_plugin "manageiq-consumption"
end

group :ui_dependencies do # Added to Bundler.require in config/application.rb
  manageiq_plugin "manageiq-decorators"
  manageiq_plugin "manageiq-ui-classic"
  # Modified gems (forked on Github)
  gem "jquery-rjs",                     "=0.1.1.3",          :source => "https://rubygems.manageiq.org"
end

group :web_server, :manageiq_default do
  gem "puma",                           "~>6.4", ">=6.4.2"
  gem "ruby-dbus" # For external auth
  gem "secure_headers",                 "~>3.9"
end

group :web_socket, :manageiq_default do
  gem "surro-gate",                     "~>1.0.5",           :require => false
  gem "websocket-driver",               "~>0.6.3",           :require => false
end

group :appliance, :optional => true do
  gem "irb",                            "=1.4.1",            :require => false # Locked to same version as the installed RPM rubygem-irb-1.4.1-142.module_el9+787+b20bfeee.noarch so that we don't bundle our own
  gem "manageiq-appliance_console",     "~>9.0", ">= 9.0.3", :require => false
  gem "rdoc",                                                :require => false # Needed for rails console
end

### Development and test gems are excluded from appliance and container builds to reduce size and license issues
group :development do
  gem "foreman"
  gem "manageiq-style",                 "~>1.5.0",           :require => false
  gem "PoParser"
  gem "yard",                           ">= 0.9.36"
end

group :test do
  gem "brakeman",                       "~>5.4",             :require => false
  gem "bundler-audit",                                       :require => false
  gem "capybara",                       "~>2.5.0",           :require => false
  gem "db-query-matchers",              "~>0.10.0"
  gem "factory_bot",                    "~>5.1",             :require => false
  gem "simplecov",                      ">=0.21.2",          :require => false
  gem "timecop",                        "~>0.9", "!= 0.9.7", :require => false
  gem "vcr",                            "~>6.1",             :require => false
  gem "webmock",                        "~>3.7",             :require => false
end

group :development, :test do
  gem "parallel_tests",                 "~>4.4", :require => false
  gem "routes_lazy_routes"
  gem "rspec-rails",                    "~>4.0.1"
end
