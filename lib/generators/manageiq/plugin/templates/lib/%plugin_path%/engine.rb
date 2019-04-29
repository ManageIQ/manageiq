<% exploded_class_name do %>
  class Engine < ::Rails::Engine
    isolate_namespace <%= class_name %>
  end
<% end %>
