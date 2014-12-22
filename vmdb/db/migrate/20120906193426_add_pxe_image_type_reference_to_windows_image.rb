class AddPxeImageTypeReferenceToWindowsImage < ActiveRecord::Migration
  def up
    change_table :windows_images do |t|
      t.belongs_to :pxe_image_type, :type => :bigint
    end
  end

  def down
    change_table :windows_images do |t|
      t.remove_belongs_to :pxe_image_type
    end
  end
end
