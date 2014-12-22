class CreatePxeImageTypes < ActiveRecord::Migration
  def up
    create_table :pxe_image_types do |t|
      t.string  :name
      t.string  :provision_type
    end

    change_table :pxe_images do |t|
      t.belongs_to :pxe_image_type, :type => :bigint
      t.remove     :image_type
    end

    change_table :customization_templates do |t|
      t.belongs_to :pxe_image_type, :type => :bigint
      t.remove     :image_type
    end

  end

  def down
    change_table :pxe_images do |t|
      t.remove_belongs_to :pxe_image_type
      t.string            :image_type
    end

    change_table :customization_templates do |t|
      t.remove_belongs_to :pxe_image_type
      t.string            :image_type
    end

    drop_table :pxe_image_types
  end
end
