describe "Ruby 'require' leak with Pathnames" do
  context "to prevent" do
    # If this test fails, then either this repo, or one of the provider repos
    # has added a entry to `config.autoload_paths` that is a Pathname instead
    # of a raw string.  Until we upgrade to ruby >= 2.5, all Pathnames in the
    # autoload_paths/$LOAD_PATH should be converted to Strings.
    #
    # You can use the code in the expect block as a way of testing this in a
    # `bin/rails console`:
    #
    #     irb> $LOAD_PATH.select { |p| p.class == Pathname }
    #     #=> []
    #
    # More info can be found here:
    #
    #     * https://bugs.ruby-lang.org/issues/14372
    #
    it "has no Pathnames in the $LOAD_PATH" do
      expect($LOAD_PATH.select { |p| p.class == Pathname }).to be_empty
    end
  end

  if ENV["TRAVIS"] && ENV["TRAVIS_ALLOW_FAILURE"] != "true"
    context "this file can be removed when" do
      # If this test fails, then the ManageIQ project has been upgraded to a
      # version of ruby that no longer requires converting Pathnames in the
      # autoload_paths/$LOAD_PATH to strings.  This means this file can be
      # deleted and the changes in the the config/application.rb and
      # lib/manageiq/**/engine.rb files can be re-evaluated to see if changing
      # them back to Pathnames makes sense. See the following PRs for examples
      # of what was changed:
      #
      #     * https://github.com/ManageIQ/manageiq/pull/16837
      #     * https://github.com/ManageIQ/manageiq-api/pull/288
      #     * https://github.com/ManageIQ/manageiq-automation_engine/pull/146
      #     * https://github.com/ManageIQ/manageiq-ui-classic/pull/3266
      #     * https://github.com/ManageIQ/manageiq-graphql/pull/34
      #
      it "is running on ruby >= 2.5.0 on travis only" do
        ruby_2_5_0_version   = Gem::Version.new("2.5.0")
        travis_yaml          = YAML.load_file(File.expand_path("../../.travis.yml", __dir__))
        travis_ruby_versions = travis_yaml["rvm"].map { |rb_ver| Gem::Version.new(rb_ver) }
        err_msg              = "expected at least 1 ruby to be less than 2.5.0"

        expect(travis_ruby_versions.any? { |rb_ver| rb_ver < ruby_2_5_0_version }).to be_truthy, err_msg
      end
    end
  end
end
