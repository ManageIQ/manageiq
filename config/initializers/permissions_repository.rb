require 'vmdb/permission_stores'

Vmdb::PermissionStores.configure do |config|
  if Rails.env.test?
    config.backend = 'null'
  else
    config.backend = 'yaml'
    config.options[:filename] = Rails.root.join 'config', 'permissions.yml'
  end
end
Vmdb::PermissionStores.initialize!
