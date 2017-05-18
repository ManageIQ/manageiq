module ManageIQ
  module Providers
    module <%= class_name %>
      class Engine < ::Rails::Engine
        isolate_namespace ManageIQ::Providers::<%= class_name %>
      end
    end
  end
end
