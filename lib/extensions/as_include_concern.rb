module ActiveSupport
  module Dependencies
    module Loadable
      # Includes the concern given by +mod+ into the calling module, bypassing
      # Rails' autoload, and directly requiring the expected file.  This is used
      # to workaround issues with the interaction between Ruby's constant lookup
      # and Rails' const_missing (for autoload) where only the tail of the
      # module namespace is resolved and thus the expected file may not get
      # required.
      #
      # Example issue:
      #   class Post < ActiveRecord::Base
      #     include Post::SomeConcern
      #   end
      #
      #   class SpecialPost < Post
      #     include SpecialPost::SomeConcern
      #   end
      #
      #   The call in SpecialPost does nothing because Rails' const_missing is
      #   not triggered.  SpecialPost already has a module named SomeConcern
      #   which it obtains from Post's inclusion of a module named SomeConcern.
      #   Since the reference to SomeConcern resolves to a known module,
      #   const_missing, and thus Rails' autoload, are not triggered.
      #
      # Example fix:
      #   class Post < ActiveRecord::Base
      #     include_concern 'Post::SomeConcern'
      #   end
      #
      #   class SpecialPost < Post
      #     include_concern 'SpecialPost::SomeConcern'
      #   end
      #
      #   This now works because include_concern explicitly loads the file
      #   special_post/some_concern.rb, thus bringing in a new module. The
      #   include will then resolve to the newly brought in module.
      #
      #
      # @param mod [String] The module to include.  It will be required relative
      #   to the calling module, and if that fails it will be required with the
      #   full path.  For example, either of the following will work.
      #
      #   class SpecialPost < ActiveRecord::Base
      #     include_concern 'SomeConcern'
      #     include_concern 'SpecialPost::SomeConcern'
      #   end
      def include_concern(mod)
        begin
          to_include = "#{name}::#{mod}"
          require_dependency to_include.underscore
        rescue LoadError => err
          raise unless err.message.include?(to_include.underscore)
          to_include = mod
          require_dependency to_include.underscore
        end
        include to_include.constantize
      end
    end
  end
end
