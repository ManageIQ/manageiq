module Vmdb
  class Productization
    class DirectiveProcessor < Sprockets::DirectiveProcessor
      # require_tree_with_asset_paths is an alternative to require_tree that
      # respects the asset paths.  The require_tree directive does not do asset
      # path resolution and instead uses absolute paths, unlike the require
      # directive.  This causes any paths that are prepended to be ignored, which
      # makes overriding during precompilation impossible.
      #
      # This is a modified version of require_tree originally found here:
      #   https://github.com/sstephenson/sprockets/blob/v2.2.2/lib/sprockets/directive_processor.rb
      def process_require_tree_with_asset_paths_directive(path = ".")
        # The path must be relative and start with a `./`.
        raise ArgumentError, "require_tree_with_asset_paths argument must be a relative path" unless relative?(path)

        root = pathname.dirname                      # root => app/assets/javascripts
        directive_root = root.join(path).expand_path # if path == "foo/bar", directive_root => app/assets/javascripts/foo/bar

        unless stat(directive_root).try(:directory?)
          raise ArgumentError, "require_tree_with_asset_paths argument must be a directory"
        end

        each_entry(directive_root) do |pathname|
          next if pathname.to_s == file || stat(pathname).directory?

          basename = pathname.relative_path_from(root).to_s.gsub(/\..+$/, "")
          process_require_directive(basename)
        end
      end

      #
      # Asset logging overrides
      #

      def process_require_directive(path)
        log_resolved_asset(path)
        super
      end

      def process_require_self_directive
        log_resolved_asset(pathname)
        super
      end

      private

      def log_resolved_asset(path, include = true)
        resolved = resolved_asset(path)
        if include
          puts "  + #{resolved}"
        elsif ENV["DEBUG_PRECOMPILE"]
          puts "  - #{resolved}"
        end
      end

      def resolved_asset(path)
        resolved = context.resolve(path)
        resolved.to_s.start_with?(Rails.root.to_s) ? resolved.relative_path_from(Rails.root) : resolved
      end
    end
  end
end
