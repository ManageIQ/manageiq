class CreateFlavors < ActiveRecord::Migration
  def up
    create_table :flavors do |t|
      t.belongs_to :ems, :type => :bigint
      t.string     :name
      t.string     :description
      t.integer    :cpus
      t.integer    :cpu_cores
      t.bigint     :memory
    end

    add_index :flavors, :ems_id
  end

  def down
    drop_table :flavors
  end
end
