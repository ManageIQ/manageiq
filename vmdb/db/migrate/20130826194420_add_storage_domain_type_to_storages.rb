class AddStorageDomainTypeToStorages < ActiveRecord::Migration
  def change
    add_column :storages, :storage_domain_type, :string
  end
end
