module MiqBundler
  def self.prepare
    return if @prepared
    return if ["config"].include?(ARGV.first)
    @prepared = true

    set_bundler_binstubs_path
    fix_bundler_binstub
  end

  def self.set_bundler_binstubs_path
    ENV['BUNDLE_BIN'] = "bin"
  end

  def self.fix_bundler_binstub
    # https://github.com/carlhuda/bundler/issues/1384
    # The bundler binstub, found here:
    # https://github.com/carlhuda/bundler/blob/master/lib/bundler/templates/Executable
    # does not conditionally remove a version arg, such as "_0.4.16_", and overwrites
    # the rubygems' wrapper which does do this. This causes issues running
    # netbeans debugger (ruby-debug-ide)

    # Remove the version arg if it exists...
    ARGV.shift if ARGV.first =~ /^_(.*)_$/ and Gem::Version.correct? $1
  end

  # Require a gem from outside the Gemfile.  This should only be used for local
  #   gems that you may want to load for your personal development in your
  #   .irbrc file, but that shouldn't be required for all developers
  #   (e.g. awesome_print, wirble, hirb, etc.).
  def self.require_without_bundler(*gems)
    activate_without_bundler(*gems)
    gems.collect { |g| require g }
  end

  # Activate a gem from outside the Gemfile. Could be considered harmful.
  #   Might be useful for .irbrc and friends. It's a slow activation, but
  #   after activation, files from the activated gems will be available for
  #   normal require.
  #   Found here: https://gist.github.com/794915#gistcomment-28586
  def self.activate_without_bundler(*gems)
    # Bundler doesn't cripple this:
    Gem.source_index.refresh!
    # Or this:
    Gem.activate(*gems)
  ensure
    # Re-enable the bundler lockdown via bundlers #initialize hack
    Gem.send(:class_variable_set, :@@source_index, nil)
  end

  def self.include_gemfile(file, binding)
    file = File.expand_path(file, File.dirname(__FILE__))
    eval(File.read(file), binding, file)
  end
end

# All that for this...
MiqBundler.prepare
