class AddVmHabtmKeyPairs < ActiveRecord::Migration
  def change
    create_table :key_pairs_vms, :id => false do |t|
      t.references :authentication, :type => :bigint
      t.references :vm, :type => :bigint
    end
  end
end
