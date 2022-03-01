module BrakemanExcludesPatch
  # Original code can be found here:
  # https://github.com/presidentbeef/brakeman/blob/5a1eb49216b7087243f5ed0f17c90ea8ca696df1/lib/brakeman/app_tree.rb#L204-L216
  #
  # Brakeman silently excludes the vendor directory as of 5.0 by default, see:
  # https://github.com/presidentbeef/brakeman/commit/89e40fef82a2144aaec5f6203959df39aed22c17
  # This exclusion occurs AFTER inclusion paths via configuration such as engine paths.
  # The patch below overrides this behavior and only excludes vendor/ files that aren't opted-in via engine paths.
  def reject_global_excludes(paths)
    paths.reject do |path|
      relative_path = path.relative

      # Add last check for engine_paths
      if @skip_vendor and relative_path.include? 'vendor/' and @engine_paths.none? { |p| path.absolute.include?(p) }
        true
      else
        Brakeman::AppTree::EXCLUDED_PATHS.any? do |excluded|
          relative_path.include? excluded
        end
      end
    end
  end
end
