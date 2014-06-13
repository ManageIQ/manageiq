class AddBitnessToHardwares < ActiveRecord::Migration
  def change
    add_column :hardwares, :bitness, :integer
  end
end
