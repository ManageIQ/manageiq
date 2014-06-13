module Vmdb
  class Productization
    def prepare
      prepare_asset_paths
      prepare_asset_precompilation
      prepare_asset_directive_processor
      add_logging_to_rake_assets_precompile
    end

    private

    # Prepend the productization/assets directories to the asset paths.
    def prepare_asset_paths
      pattern = Rails.root.join("productization", "assets", "*")
      paths   = Dir.glob(pattern).select { |f| File.directory?(f) }
      Rails.application.config.assets.paths.unshift(*paths)
    end

    # Override Rails' default precompilation of assets, which excludes all .js
    #   and .css files except application.js and application.css, to also
    #   process productization.js and productization.css if available.  In
    #   addition, include printing of resolved assets.
    #
    #   The original value is located at:
    #     https://github.com/rails/rails/blob/v3.2.15/railties/lib/rails/application/configuration.rb#L48-L49
    def prepare_asset_precompilation
      Rails.application.config.assets.precompile = [
        Proc.new do |path|
          include =
            !File.extname(path).in?(['.js', '.css']) ||
            path =~ /(?:\/|\\|\A)(application|productization)\.(css|js)$/

          resolved = Rails.application.assets.resolve(path)
          resolved = resolved.relative_path_from(Rails.root) if resolved.to_s.start_with?(Rails.root.to_s)
          if include
            puts "+ #{resolved}"
          elsif ENV["DEBUG_PRECOMPILE"]
            puts "- #{resolved}"
          end

          include
        end
      ]
    end

    # Replace the default Sprockets::DirectiveProcessor with our overriden one
    #   that properly handles overriding the asset paths.
    def prepare_asset_directive_processor
      replace_directive_processor('text/css')
      replace_directive_processor('application/javascript')
    end

    def replace_directive_processor(type)
      Rails.application.assets.unregister_processor(type, Sprockets::DirectiveProcessor)
      Rails.application.assets.register_processor(type, DirectiveProcessor)
    end

    # Override Rails' rake task component for precompilation to log separators on
    # each call.  The method is defined at the top-level and so must be overridden
    # in the TOPLEVEL_BINDING.
    #
    # The original source is located at:
    #   https://github.com/rails/rails/blob/v3.2.15/actionpack/lib/sprockets/assets.rake#L33-L57
    def add_logging_to_rake_assets_precompile
      TOPLEVEL_BINDING.eval <<-EORUBY
        if defined?(internal_precompile)
          def internal_precompile_with_logging(digest=nil)
            puts "== precompile with\#{"out" if digest == false} digests ================================================="
            internal_precompile_without_logging(digest)
          end
          # a la alias_method_chain
          alias :internal_precompile_without_logging :internal_precompile
          alias :internal_precompile :internal_precompile_with_logging
        end
      EORUBY
    end
  end
end
