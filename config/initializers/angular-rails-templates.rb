module Vmdb
  class Application < Rails::Application
    config.angular_templates.module_name    = 'miq.templates'
    config.angular_templates.ignore_prefix  = []
    config.angular_templates.inside_paths   = ['app/views/static']
    config.angular_templates.markups        = %w(haml)
    config.angular_templates.extension      = 'html'
  end
end
