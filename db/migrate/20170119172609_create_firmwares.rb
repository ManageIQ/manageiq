class CreateFirmwares < ActiveRecord::Migration[5.0]
  def change
    create_table :firmwares do |t|
      t.string  :name
      t.string  :build
      t.string  :version
      t.string  :ph_server_uuid, index: true
      t.datetime  :release_date
      t.timestamps
    end
  end
end
