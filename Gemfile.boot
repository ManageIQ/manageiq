gem "rails",                           "~> 5.0.x", :git => "git://github.com/rails/rails.git", :branch => "5-0-stable"
gem "rails-controller-testing",        :require => false
gem "config",                          "~>1.1.0", :git => "git://github.com/ManageIQ/config.git", :branch => "overwrite_arrays"
gem "sprockets-es6",                  "~>0.9.0",  :require => "sprockets/es6"

# Vendored and required
gem "ruport",                         "=1.7.0",                       :git => "git://github.com/ManageIQ/ruport.git", :tag => "v1.7.0-3"

# Not vendored, but required
gem "default_value_for",              "~>3.0.2.alpha-miq.1", :git => "git://github.com/jrafanie/default_value_for.git", :branch => "rails-50" # https://github.com/FooBarWidget/default_value_for/pull/57
gem "hamlit-rails",                   "~>0.1.0"
gem "high_voltage",                   "~>2.4.0"
gem "secure_headers",                 "~>3.0.0"

# Needed by the REST API
gem "gettext_i18n_rails",             "~>1.4.0"
gem "gettext_i18n_rails_js",          "~>1.0.3"
gem "fast_gettext",                   "~>1.1.0"
gem "paperclip",                      "~>4.3.0"

# Not vendored and not required
gem "ancestry",                       "~>2.1.0",   :require => false
gem "ansible_tower_client",           "~>0.3.0",   :require => false
gem "dalli",                          "~>2.7.4",   :require => false
gem "hamlit",                         "~>2.0.0",   :require => false
gem "net_app_manageability",          ">=0.1.0",   :require => false
gem "omniauth",                       "~>1.3.1",   :require => false
gem "omniauth-google-oauth2",         "~>0.2.6"
gem "ruby_parser",                    "~>3.7",     :require => false

### Start of gems excluded from the appliances.
# The gems listed below do not need to be packaged until we find it necessary or useful.
# Only add gems here that we do not need on an appliance.
#
unless ENV['APPLIANCE']
  group :test do
    gem "capybara",         "~>2.5.0",  :require => false
    gem "factory_girl",     "~>4.5.0",  :require => false
  end

  group :development, :test do
    gem "rspec-rails",      "~>3.5.x"
  end
end

eval_gemfile(File.expand_path("gems/pending/Gemfile.boot", __dir__))
