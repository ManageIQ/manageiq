# Use this file to set/override Jasmine configuration options
# You can remove it if you don't need it.
# This file is loaded *after* jasmine.yml is interpreted.
#
Jasmine.configure do |config|
  # The gemified version of Jasmine uses the gemified version of PhantomJS
  # which auto-installs it if it can't find your installation in ~/.phantomjs
  # Travis already has a version of PhantomJS installed in a different
  # location, so the gem will auto-install even if it's pointless.  Also,
  # gemified PhantomJS hardcodes install URLs from BitBucket which times out
  # and causes failed builds.
  #
  # TLDR: Don't install auto-install PhantomJS on CI. In Travis we trust.
  config.prevent_phantom_js_auto_install = true if ENV['CI']
end
