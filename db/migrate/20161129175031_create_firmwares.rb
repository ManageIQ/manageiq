class CreateFirmwares < ActiveRecord::Migration[5.0]
  def change
    create_table :firmwares do |t|
      t.bigint  :ph_server_id
      t.string  :name
      t.string  :build
      t.string  :version
      t.datetime  :release_date
      t.timestamps
    end
  end
end
