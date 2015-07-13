class AddEmsRefToSnapshots < ActiveRecord::Migration
  def change
    add_column :snapshots, :ems_ref, :string
  end
end
