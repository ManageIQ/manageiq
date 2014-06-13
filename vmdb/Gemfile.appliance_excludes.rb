group :development do
  gem "ruby-prof",                    :require => false
  gem "win32console",                 :require => false if RUBY_PLATFORM =~ /mingw/

  # gruff
  # rmagick (~>2.13.1)
  gem "ruby-graphviz",                :require => false  # Used by state_machine:draw Rake Task
end

group :test do
  gem "brakeman",         "~>2.0",    :require => false
  gem "bullet",                       :require => false

  gem "vcr",              "~>2.4.0",  :require => false
  gem "webmock",          "~>1.11.0", :require => false # Although VCR complains, we're forced to use 1.11.0 since we're locked
                                                        #   on excon 0.20.0.  webmock 1.11.0 is the only version that works
                                                        #   properly against excon 0.20.0.

  gem "shoulda-matchers", "~>1.0.0",  :require => false
  gem "factory_girl",     "~>4.1.0",  :require => false

  gem "capybara",         "~>2.1.0",  :require => false
end

group :development, :test, :metric_fu do
  gem "rspec-rails",      "~>2.12.0"
end

group :metric_fu do
  gem "metric_fu",           :require => false, :git => "git://github.com/ManageIQ/metric_fu.git", :tag => "v3.0.0-3"
  gem "roodi",               :require => false, :git => "git://github.com/ManageIQ/roodi.git", :tag => "v2.2.0-1"

  # For simplecov-rcov-text, lock onto a specific commit from the master branch
  #   until the author releases a new version.  This commit fixes the following
  #   error that occurs after a successful run of the specs:
  #
  #     simplecov-rcov-text.rb:17:in `write': "\xC2" from ASCII-8BIT to UTF-8 (Encoding::UndefinedConversionError)
  #
  #   See https://github.com/kina/simplecov-rcov-text/pull/3
  gem "simplecov-rcov-text", :require => false, :git => "git://github.com/kina/simplecov-rcov-text.git", :ref => "3d05aaa5abcc1bf177e143ad86ba14ae69c6d57b"
end

# Debuggers:
#   Enable either the rubymine debugger OR one of the CLI debuggers in your Gemfile, not both.
#     http://devnet.jetbrains.net/thread/431168?tstart=0
#   After creating/updating the Gemfile.dev.rb as described below, run bundle install.
#
# for rubymine: the latest rubymine should install the correct debuggers and require them automatically, but if needed
# copy the following lines to Gemfile.dev.rb and start the debugger through rubymine
#   gem "ruby-debug-base19x", "~> 0.11.30.pre10", :require => false
#   gem "ruby-debug-ide",     "~> 0.4.17.beta14", :require => false
#
# for the CLI fast debugger: copy the following line to Gemfile.dev.rb and start the debugger via: require 'debugger'; debugger
#   gem "debugger",           "~>1.2.0",          :require => false
#
# for the Old CLI fast debugger: copy the following line to Gemfile.dev.rb and start the debugger via: require 'ruby-debug'; debugger
#   gem "ruby-debug19",       "~>0.11.6",         :require => false
#   gem "ruby-debug-base19",  "~>0.11.25",        :require => false
#
# for the ruby debug standard library start the debugger via: require 'debug'; debugger
