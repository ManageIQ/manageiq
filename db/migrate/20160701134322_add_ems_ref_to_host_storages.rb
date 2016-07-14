class AddEmsRefToHostStorages < ActiveRecord::Migration[5.0]
  def change
    add_column :host_storages, :ems_ref, :string
  end
end
