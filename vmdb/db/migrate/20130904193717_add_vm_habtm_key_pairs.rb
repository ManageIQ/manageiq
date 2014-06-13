class AddVmHabtmKeyPairs < ActiveRecord::Migration
  def change
    create_table :key_pairs_vms, :id => false do |t|
      t.references :authentication
      t.references :vm
    end
  end
end
