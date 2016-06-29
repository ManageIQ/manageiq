raise "Ruby versions less than 2.2 are unsupported!" if RUBY_VERSION < "2.2.0"
source 'https://rubygems.org'

# Not locally modified and not required
gem "addressable",             "~> 2.4",            :require => false
gem "awesome_spawn",           "~> 1.3",            :require => false
gem "bcrypt",                  "~> 3.1.10",         :require => false
gem "binary_struct",           "~> 2.1",            :require => false
gem "ezcrypto",                "=0.7",              :require => false
gem "image-inspector-client",  "~>1.0.2",           :require => false
gem "iniparse",                                     :require => false
gem "kubeclient",              "=1.1.3",            :require => false
gem "hawkular-client",         "=2.0.0",            :require => false
gem "linux_admin",             "~>0.16.0",          :require => false
gem "log4r",                   "=1.1.8",            :require => false
gem "memoist",                 "~>0.14.0",          :require => false
gem "memory_buffer",           ">=0.1.0",           :require => false
gem "more_core_extensions",    "~>2.0.0",           :require => false
gem "pg",                      "~>0.18.2",          :require => false
gem "sys-uname",               "~>1.0.1",           :require => false
gem 'sys-proctable',           "~>1.1.0",           :require => false
gem "uuidtools",               "~>2.1.3",           :require => false

# Linux-only section
if RbConfig::CONFIG["host_os"].include?("linux")
  gem "linux_block_device", ">=0.1.0", :require => false
end

# Locally modified but not required
gem "handsoap", "~>0.2.5", :require => false, :git => "git://github.com/ManageIQ/handsoap.git", :tag => "v0.2.5-3"
gem "rubywbem",            :require => false, :git => "git://github.com/ManageIQ/rubywbem.git", :branch => "rubywbem_0_1_0"


### Start of gems excluded from the appliances.
# The gems listed below do not need to be packaged until we find it necessary or useful.
# Only add gems here that we do not need on an appliance.
#
unless ENV['APPLIANCE']
  group :test do
    gem "coveralls",                    :require => false
    gem "timecop",       "~>0.7.3",     :require => false
    gem "vcr",           "~>2.6",       :require => false
    gem "webmock",       "~>1.12",      :require => false
  end
end
