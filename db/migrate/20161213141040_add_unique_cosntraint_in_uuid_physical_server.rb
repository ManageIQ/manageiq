class AddUniqueCosntraintInUuidPhysicalServer < ActiveRecord::Migration[5.0]
  def change
    add_index :physical_servers,  :uuid,  :unique =>  true
  end
end
