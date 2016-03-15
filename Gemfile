eval_gemfile(File.expand_path("gems/pending/Gemfile", __dir__))

#
# VMDB specific gems
#

gem "rails",                           "~> 5.0.x", :git => "git://github.com/rails/rails.git", :branch => "master"
gem "rails-controller-testing",        :require => false
gem "activemodel-serializers-xml",     :require => false # required by draper: https://github.com/drapergem/draper/issues/697
gem "activerecord-session_store",      "~>0.1.2", :require => false

# Local gems
path "gems/" do
  gem "manageiq_foreman", :require => false
  gem "manageiq-providers-amazon"
end

# Client-side dependencies
gem "angular-ui-bootstrap-rails",     "~>0.13.0"
gem "codemirror-rails",               "=4.2"
gem "jquery-hotkeys-rails"
gem "jquery-rails",                   "~>4.0.4"
gem "jquery-rjs",                     "=0.1.1",                       :git => "git://github.com/matthewd/jquery-rjs.git", :branch => "rails5" # https://github.com/amatsuda/jquery-rjs/pull/4
gem "lodash-rails",                   "~>3.10.0"
gem "patternfly-sass",                "~>3.2.0"
gem "sass-rails"
gem "sprockets-es6",                  "~>0.9.0",  :require => "sprockets/es6"

# Vendored and required
gem "ruport",                         "=1.7.0",                       :git => "git://github.com/ManageIQ/ruport.git", :tag => "v1.7.0-3"


# Vendored but not required
gem "net-ldap",                       "~>0.7.0",   :require => false
gem "rubyrep",                        "=1.2.0",    :require => false, :git => "git://github.com/matthewd/rubyrep.git", :branch => "rails5"
gem "simple-rss",                     "~>1.3.1",   :require => false
gem "winrm",                          "~>1.7.2",   :require => false
gem "ziya",                           "=2.3.0",    :require => false, :git => "git://github.com/ManageIQ/ziya.git", :tag => "v2.3.0-2"

# Not vendored, but required
gem "mime-types",                     "~>2.6.1",   :require => "mime/types/columnar"
gem "acts_as_list",                   "~>0.7.2"
gem "acts_as_tree",                   "~>2.1.0"  # acts_as_tree needs to be required so that it loads before ancestry
# In 1.9.3: Time.parse uses british version dd/mm/yyyy instead of american version mm/dd/yyyy
# american_date fixes this to be compatible with 1.8.7 until all callers can be converted to the 1.9.3 format prior to parsing.
# See miq_expression_spec Date/Time Support examples.
# https://github.com/jeremyevans/ruby-american_date
gem "american_date"
gem "azure-armrest",                  "~>0.2.0"
gem "color",                          "~>1.8"
gem "default_value_for",              "~>3.0.1", :git => "git://github.com/matthewd/default_value_for.git", :branch => "rails-50" # https://github.com/FooBarWidget/default_value_for/pull/57
gem "draper",                         "~>2.1.0", :git => "git://github.com/janraasch/draper.git", :branch => "feature/rails5-compatibility" # https://github.com/drapergem/draper/pull/712
gem "hamlit-rails",                   "~>0.1.0"
gem "high_voltage",                   "~>2.4.0"
gem "nakayoshi_fork",                 "~>0.0.3"  # provides a more CoW friendly fork (GC a few times before fork)
gem "novnc-rails",                    "~>0.2"
gem "outfielding-jqplot-rails",       "= 1.0.8"
gem "puma",                           "~>2.13"
gem "recursive-open-struct",          "~>0.6.1"
gem "responders",                     "~>2.0"
gem "secure_headers",                 "~>3.0.0"
gem "spice-html5-rails"
#gem "thin",                           "~>1.6.0"  # Used by rails server through rack

# Needed by the REST API
gem "gettext_i18n_rails",             "~>1.4.0"
gem "gettext_i18n_rails_js",          "~>1.0.3"
gem "jbuilder",                       "~>2.3.1"
gem "paperclip",                      "~>4.3.0"
gem "rails-i18n",                     "~>5.x"

# Needed by External Auth
gem "ruby-dbus"

# Not vendored and not required
gem "ancestry",                       "~>2.1.0",   :require => false
gem "ansible_tower_client",           "~>0.0.1",   :require => false, :git => "git://github.com/ManageIQ/ansible_tower_client.git", :branch => "master"
gem "aws-sdk",                        "~>2.2.19",  :require => false
gem "dalli",                          "~>2.7.4",   :require => false
gem "elif",                           "=0.1.0",    :require => false
gem "google-api-client",              "~>0.8.0",   :require => false
gem "fog-google",                     "~>0.1.0",   :require => false
gem "hamlit",                         "~>2.0.0",   :require => false
gem "inifile",                        "~>3.0",     :require => false
gem "logging",                        "~>1.6.1",   :require => false  # Ziya depends on this
gem "net_app_manageability",          ">=0.1.0",   :require => false
gem "net-ping",                       "~>1.7.4",   :require => false
gem "net-ssh",                        "~>2.9.2",   :require => false
gem "omniauth",                       "~>1.3.1",   :require => false
gem "omniauth-google-oauth2",         "~>0.2.6"
gem "open4",                          "~>1.3.0",   :require => false
gem "ovirt_metrics",                  :git => "git://github.com/matthewd/ovirt_metrics.git", :branch => "rails5", :require => false # https://github.com/ManageIQ/ovirt_metrics/pull/8
gem "ruby_parser",                    "~>3.7",     :require => false
gem "ruby-progressbar",               "~>1.7.0",   :require => false
gem "rufus-scheduler",                "~>3.1.3",   :require => false
gem "rugged",                         "~>0.23.0",  :require => false
gem "savon",                          "~>2.2.0",   :require => false  # Automate uses this for simple SOAP Integration
gem "snmp",                           "~>1.2.0",   :require => false
gem "uglifier",                       "~>2.7.1",   :require => false
gem "sshkey",                         "~>1.8.0",   :require => false


### Start of gems excluded from the appliances.
# The gems listed below do not need to be packaged until we find it necessary or useful.
# Only add gems here that we do not need on an appliance.
#
unless ENV['APPLIANCE']
  group :development do
    gem "rubocop",          "~>0.37.2", :require => false
    gem "ruby-graphviz",                :require => false  # Used by state_machine:draw Rake Task
  end

  group :test do
    gem "sqlite3",                      :require => false

    gem "brakeman",         "~>3.1.0",  :require => false
    gem "capybara",         "~>2.5.0",  :require => false
    gem "factory_girl",     "~>4.5.0",  :require => false
    gem "vcr",              "~>2.6",    :require => false
    gem "webmock",          "~>1.12",   :require => false
  end

  group :development, :test do
    gem "rspec-rails",      "~>3.5.x"
  end
end

# Assets from rails-assets.org
source "https://rails-assets.org" do
  gem "rails-assets-angular",                         "~>1.4.3"
  gem "rails-assets-angular-animate",                 "~>1.4.3"
  gem "rails-assets-angular-mocks",                   "~>1.4.3"
  gem "rails-assets-angular-patternfly-sass",         "~>3.2.0"
  gem "rails-assets-angular-sanitize",                "~>1.4.3"
  gem "rails-assets-bootstrap-datepicker",            "~>1.4.0"
  gem "rails-assets-bootstrap-filestyle",             "~>1.2.1"
  gem "rails-assets-bootstrap-hover-dropdown",        "~>2.0.11"
  gem "rails-assets-bootstrap-select",                "~>1.7.3"
  gem "rails-assets-c3",                              "~>0.4.10"
  gem "rails-assets-himdel--jquery.observe_field",    "~>0.1.0"
  gem "rails-assets-jasmine-jquery",                  "~>2.1.1"
  gem "rails-assets-jquery-1.8",                      "~>1.8.3"
  gem "rails-assets-jquery-ujs",                      "~>1.1.0"
  gem "rails-assets-jqueryui",                        "~>1.9.2"
  gem "rails-assets-bootstrap-switch",                "~>3.3.2"
  gem "rails-assets-angular-bootstrap-switch",        "~>0.4.1"
  gem "rails-assets-kubernetes-topology-graph",       "= 0.0.22"
  gem "rails-assets-moment",                          "~>2.10.3"
  gem "rails-assets-moment-strftime",                 "~>0.1.5"
  gem "rails-assets-moment-timezone",                 "~>0.4.0"
  gem "rails-assets-numeral",                         "~>1.5.3"
  gem "rails-assets-slickgrid",                       "~>2.1.0"
  gem "rails-assets-spin.js",                         "~>2.3.2"
  gem "rails-assets-sprintf",                         "~>1.0.3"
  gem "rails-assets-xml_display",                     "~>0.1.1"
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
