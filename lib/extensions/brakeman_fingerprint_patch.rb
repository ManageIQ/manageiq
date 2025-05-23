# Brakeman fingerprints account for the file location as part of the fingerprint
# digest. The fingerprint uses the file's relative path, but assumes that all
# files being scanned will be under the app_tree root directory, providing a
# consistent file path regardless of the system it is run on.
#
# For engines, however this is not always the case. Engines can come from gems
# and gems can be installed basically anywhere on the system depending on how
# ruby is installed and configured, and even depending on which Ruby version
# manager is used. Additionally, in CI gems are typically installed in a vendor
# directory, and locally gems can be configured as git-based or path-based.
# Because of this, the file path and the fingerprint can vary widely between
# local dev and CI, causing problems when trying to ignore issues. For example,
#
#   git-based engine locally     | ../../.gem/ruby/3.1.5/bundler/gems/manageiq-ui-classic-df1d9535ef51/app/controllers/application_controller.rb
#   git-based engine on CI       | vendor/bundle/ruby/3.0.0/bundler/gems/manageiq-ui-classic-df1d9535ef51/app/controllers/application_controller.rb
#   path-based engine locally    | ../manageiq-ui-classic/app/controllers/application_controller.rb
#   version-based engine locally | ../../.gem/ruby/3.1.5/bundler/gems/manageiq-ui-classic-0.1.0/app/controllers/application_controller.rb
#
# This patch introduces a way to "remove" the leading path for files that reside
# in engines. This removal provides a consistent file path for the fingerprint
# method. For example, all of the above will appear like
#
#   (engine:manageiq-ui-classic) app/controllers/application_controller.rb
#
# NOTE: This patch only modifies what is necessary to make the
# test:security:brakeman test suite work, namely fingerprint and the json
# reporter (which leverages to_hash). It does not modify things such as the
# the text reporter (CLI output) nor the interactive ignore.
module BrakemanFingerprintPatch
  def self.rails_engine_paths
    # We sort by the path depth so that if an engine is nested within another
    # engine then later when we go to remove the engine path, we start with the
    # "deepest" engine first.
    #
    # For example, if we are scanning from manageiq-ui-classic, and there is an
    # issue in manageiq-api, then the path to the issue will appear like
    #
    #   /Users/user/dev/manageiq-ui-classic/vendor/bundle/ruby/3.1.5/bundler/gems/manageiq-api-968f4c010f2f/app/controllers/api/base_controller.rb
    #
    # When we replace the engine path, since this issue is in the manageiq-api
    # engine, we want to replace it with the "deeper" path to manageiq-api and
    # not the manageiq-ui-classic leading path
    @rails_engine_paths ||= ::Rails::Engine.subclasses.map { |e| e.root.to_s << "/" }.sort_by { |p| -p.count("/") }
  end

  # Removes any leading engine paths if the file is an engine, and replaces with
  # `(engine:<engine_name>)`
  #
  # NOTE: Ideally this code should use the in_engine_paths? method (that is
  # patched in brakeman_excludes_patch.rb), however Brakeman::Warning doesn't
  # have a reference to the app_tree where that method is defined, as warnings
  # are standalone objects.
  def file_string
    engine_path = BrakemanFingerprintPatch.rails_engine_paths.detect { |p| self.file.absolute.start_with?(p) }
    if engine_path.nil? || (Rails.root.to_s.start_with?(engine_path) && self.file.absolute.start_with?(Rails.root.to_s))
      self.file.relative
    else
      engine_name = File.basename(engine_path).sub(/-\h+$/, "").sub(/-(?:\d+\.)+\d+$/, "")
      engine_relative = self.file.absolute.sub(engine_path, "")
      "(engine:#{engine_name}) #{engine_relative}"
    end
  end

  # This method is copied from brakeman (https://github.com/presidentbeef/brakeman/blob/e4f49f64d263f8001bac62eec182ad417152776d/lib/brakeman/warning.rb#L250-L257)
  # in order to modify the file_string component of the digest to account for engine support.
  def fingerprint
    loc = self.location
    location_string = loc && loc.sort_by { |k, v| k.to_s }.inspect
    warning_code_string = sprintf("%03d", @warning_code)
    code_string = @code.inspect

    Digest::SHA2.new(256).update("#{warning_code_string}#{code_string}#{location_string}#{file_string}#{self.confidence}").to_s
  end

  # This method overrides the .to_hash method from brakeman (https://github.com/presidentbeef/brakeman/blob/e4f49f64d263f8001bac62eec182ad417152776d/lib/brakeman/warning.rb#L288-L310)
  # in order to modify the file value to account for engine support.
  def to_hash(absolute_paths: true)
    super.tap do |h|
      h[:file] = (absolute_paths ? self.file.absolute : file_string)
    end
  end
end
