class CreateFirmwares < ActiveRecord::Migration[5.0]
  def change
    create_table :firmwares do |t|
      t.string   :name
      t.string   :build
      t.string   :version
      t.datetime :release_date
      t.bigint   :resource_id
      t.string   :resource_type
      t.timestamps
      t.index %w(resource_id resource_type)
    end
  end
end
