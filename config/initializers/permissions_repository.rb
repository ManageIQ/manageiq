require 'permission_stores'

Vmdb::PermissionStores.configure do |config|
  if Rails.env.test?
    config.backend = 'null'
  else
    config.backend = 'yaml'
    config.options[:filename] = File.join Rails.root, 'config', 'permissions.yml'
  end
end
Vmdb::PermissionStores.initialize!
