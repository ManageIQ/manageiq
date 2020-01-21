require 'vmdb/permission_stores'

Vmdb::PermissionStores.configure do |config|
  yaml_filename = Rails.root.join('config', 'permissions.yml')
  if File.exist?(yaml_filename)
    config.backend = 'yaml'
    config.options[:filename] = yaml_filename
  else
    config.backend = 'null'
  end
end
Vmdb::PermissionStores.initialize!
