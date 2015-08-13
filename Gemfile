eval_gemfile(File.expand_path("gems/pending/Gemfile", __dir__))

#
# VMDB specific gems
#

gem "rails",                           RAILS_VERSION
gem "activerecord-deprecated_finders", "~>1.0.4",     :require => "active_record/deprecated_finders"

# Client-side dependencies
gem "jquery-rjs", "=0.1.1", :git => 'https://github.com/amatsuda/jquery-rjs.git'
gem 'angularjs-rails', '~>1.4.3'
gem 'angular-ui-bootstrap-rails', '~> 0.13.0'
gem 'momentjs-rails', '~> 2.10.3'
gem 'jquery-rails', "~>4.0.4"
gem 'jquery-hotkeys-rails'
gem 'codemirror-rails', "=4.2"
gem 'lodash-rails', '~> 3.10.0'

# On MS Windows run "bundle config --local build.libv8 --with-system-v8" first

gem 'sass-rails'
gem 'patternfly-sass', "~>1.3.1"
gem 'bootstrap-datepicker-rails'

# Vendored and required
gem "ruport",                         "=1.7.0",                          :git => "git://github.com/ManageIQ/ruport.git", :tag => "v1.7.0-2"

# Vendored but not required
gem "net-ldap",                       "~>0.7.0",      :require => false
gem "rubyrep",                        "=1.2.0",       :require => false, :git => "git://github.com/ManageIQ/rubyrep.git", :tag => "v1.2.0-7"
gem "simple-rss",                     "~>1.3.1",      :require => false
gem "winrm",                          "=1.1.3",       :require => false, :git => "git://github.com/ManageIQ/WinRM.git", :tag => "v1.1.3-1"
gem "ziya",                           "=2.3.0",       :require => false, :git => "git://github.com/ManageIQ/ziya.git", :tag => "v2.3.0-2"

# Not vendored, but required
gem "acts_as_list",                   "~>0.1.4"
gem "acts_as_tree",                   "~>2.1.0"  # acts_as_tree needs to be required so that it loads before ancestry
# In 1.9.3: Time.parse uses british version dd/mm/yyyy instead of american version mm/dd/yyyy
# american_date fixes this to be compatible with 1.8.7 until all callers can be converted to the 1.9.3 format prior to parsing.
# See miq_expression_spec Date/Time Support examples.
# https://github.com/jeremyevans/ruby-american_date
gem "american_date"
gem "default_value_for",              "~>3.0.1"
gem "thin",                           "~>1.6.0"  # Used by rails server through rack
gem "puma",                                                              :git => "git://github.com/puma/puma.git", :ref => "7e5b78861097be62912245f93d0187bb975f7753"
gem "bcrypt",                         "3.1.10"
gem 'outfielding-jqplot-rails',       "= 1.0.8"
gem "responders",                     "~> 2.0"
gem 'secure_headers'
gem 'mime-types'
# Needed by the REST API
gem "jbuilder",                       "~>2.3.1"
gem "gettext_i18n_rails"
gem 'rails-i18n', github: 'svenfuchs/rails-i18n', branch: 'master'
gem 'acts_as_tenant',                 "~>0.3.9"
gem 'paperclip',                      "~>4.3.0"

# Not vendored and not required
gem "ancestry",                       "~>2.1.0",      :require => false
gem "aws-sdk",                        "~>1.56.0",     :require => false
gem 'dalli',                          "~>2.7.4",      :require => false
gem "elif",                           "=0.1.0",       :require => false
gem "hamlit",                         "~>1.7.2",      :require => false
gem 'hamlit-rails',                   "~>0.1.0"
gem "inifile",                        "~>3.0",        :require => false
gem "logging",                        "~>1.6.1",      :require => false  # Ziya depends on this
gem "net_app_manageability",          ">=0.1.0",      :require => false
gem "net-ping",                       "~>1.7.4",      :require => false
gem "net-sftp",                       "~>2.0.5",      :require => false
gem "net-ssh",                        "~>2.9.2",      :require => false
gem "open4",                          "~>1.3.0",      :require => false
gem "ovirt_metrics",                  "~>1.1.0",      :require => false
gem "pg",                             "~>0.18.2",     :require => false
gem 'ruby_parser',                    "~>3.7",        :require => false
gem "ruby-progressbar",               "~>0.0.10",     :require => false
gem "rufus-scheduler",                "~>2.0.19",     :require => false
gem "savon",                          "~>2.2.0",      :require => false  # Automate uses this for simple SOAP Integration
gem "snmp",                           "~>1.2.0",      :require => false
gem "uglifier",                       "~>2.7.1",      :require => false
gem "novnc-rails",                    "~>0.2"
gem 'spice-html5-rails'


### Start of gems excluded from the appliances.
# The gems listed below do not need to be packaged until we find it necessary or useful.
# Only add gems here that we do not need on an appliance.
#
unless ENV['APPLIANCE']
  group :development do
    gem "ruby-prof",                    :require => false

    gem "ruby-graphviz",                :require => false  # Used by state_machine:draw Rake Task
    # used for finding translations
    gem "gettext",          "3.1.4",    :require => false
  end

  group :test do
    gem "brakeman",         "~>3.0",    :require => false

    gem "shoulda-matchers", "~>1.0.0",  :require => false
    gem "factory_girl",     "~>4.5.0",  :require => false

    gem "capybara",         "~>2.1.0",  :require => false
  end

  group :development, :test do
    gem "rspec-rails",      "~>2.14.0"
  end
end

# Assets from rails-assets.org
source 'https://rails-assets.org' do
  gem 'rails-assets-c3', '~> 0.4.10'
  gem 'rails-assets-bootstrap-select', '~> 1.5.4'
  gem 'rails-assets-bootstrap-hover-dropdown', '~> 2.0.11'
end

#
# Custom Gemfile modifications
#

# Load developer specific Gemfile
#   Developers can create a file called Gemfile.dev.rb containing any gems for
#   their local development.  This can be any gem under evaluation that other
#   developers may not need or may not easily install, such as rails-dev-boost,
#   any git based gem, and compiled gems like rbtrace or memprof.
dev_gemfile = File.expand_path("Gemfile.dev.rb", __dir__)
eval_gemfile(dev_gemfile) if File.exist?(dev_gemfile)

# Load other additional Gemfiles
Dir.glob("bundler.d/*.rb").each { |f| eval_gemfile(File.expand_path(f, __dir__)) }
