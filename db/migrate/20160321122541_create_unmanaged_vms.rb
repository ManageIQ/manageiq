class CreateUnmanagedVms < ActiveRecord::Migration[5.0]
  def change
    create_table :unmanaged_vms do |t|
      t.string :ip
      t.string :classification
      t.references :deployment
      t.timestamps
    end
  end
end
