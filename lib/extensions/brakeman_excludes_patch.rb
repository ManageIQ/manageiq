module BrakemanExcludesPatch
  # Override the default Brakeman in_engine_paths? method to account for running
  # brakeman from within an engine.
  #
  # When brakeman is run from within an engine, the list of engine paths will
  # include the engine's root directory. In CI, the vendor directory would then be a
  # child of an engine. The original code would then check "does this path include
  # an engine", and it always will because the engine is the parent of the vendor
  # directory.
  #
  # For example, if we are running brakeman from /path/to/manageiq-ui-classic,
  # @engine_paths will include "/path/to/manageiq-ui-classic", and the vendor
  # directory will be /path/to/manageiq-ui-classic/vendor. The original code would
  # then check if "/path/to/manageiq-ui-classic/vendor/some/file" includes
  # "/path/to/manageiq-ui-classic", and of course it always will.
  #
  # This patch takes care of that case, by honoring all engine paths _except_
  # ENGINE_ROOT itself. As this method is only called on paths that already include
  # "vendor/" we can safely ignore any file under ENGINE_ROOT/vendor.
  def in_engine_paths?(path)
    @engine_paths.any? do |p|
      if defined?(ENGINE_ROOT) && p == ENGINE_ROOT
        false # Ignore anything in the ENGINE_ROOT/vendor directory
      else
        path.absolute.include?(p)
      end
    end
  end
end
