class AddPxeMenuIdToPxeImages < ActiveRecord::Migration
  def up
    change_table :pxe_images do |t|
      t.belongs_to :pxe_menu, :type => :bigint
    end
  end

  def down
    change_table :pxe_images do |t|
      t.remove_belongs_to :pxe_menu
    end
  end
end
