class CreateIsoDatastoresAndIsoImages < ActiveRecord::Migration
  def up
    create_table :iso_datastores do |t|
      t.belongs_to :ems
      t.datetime   :last_refresh_on
    end

    create_table :iso_images do |t|
      t.string     :name
      t.belongs_to :iso_datastore
      t.belongs_to :pxe_image_type
    end
  end

  def down
    drop_table :iso_images
    drop_table :iso_datastores
  end
end
