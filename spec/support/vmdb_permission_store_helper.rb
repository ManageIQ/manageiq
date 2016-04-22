require 'tempfile'

def stub_vmdb_permission_store
  original_store = Vmdb::PermissionStores.instance
  yield
ensure
  Vmdb::PermissionStores.instance = original_store
end

def stub_vmdb_permission_store_with_types(types)
  stub_vmdb_permission_store do
    Tempfile.create(%w(config yml)) do |f|
      f.write(types.to_yaml)
      f.close

      Vmdb::PermissionStores.configure do |config|
        config.backend = 'yaml'
        config.options[:filename] = f.path
      end
      Vmdb::PermissionStores.initialize!

      yield
    end
  end
end
