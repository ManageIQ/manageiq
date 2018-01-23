module ManageIQ
  module Providers
    module <%= class_name %>
      class Engine < ::Rails::Engine
        isolate_namespace ManageIQ::Providers::<%= class_name %>

        # NOTE:  If you are going to make changes to autoload_paths, please make
        # sure they are all strings.  Rails will push these paths into the
        # $LOAD_PATH.
        #
        # More info can be found in the ruby-lang bug:
        #
        #   https://bugs.ruby-lang.org/issues/14372
        #
        # If you have no need to add any autoload_paths in this manageiq
        # plugin, feel free to delete this section.
        #
        # Examples:
        #
        # config.autoload_paths << root.join("app", "models").to_s
        # config.autoload_paths << root.join("lib", "my_provider").to_s
        # config.autoload_paths << Rails.root.join("app", "models", "aliases").to_s
      end
    end
  end
end
