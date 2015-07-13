class AddImageTypeToPxeImagesAndCustomizationTemplates < ActiveRecord::Migration
  def self.up
    add_column    :pxe_images,              :image_type,    :string
    add_column    :customization_templates, :image_type,    :string
  end

  def self.down
    remove_column :pxe_images,              :image_type
    remove_column :customization_templates, :image_type
  end
end
