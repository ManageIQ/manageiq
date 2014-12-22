class CreatePxeMenusTable < ActiveRecord::Migration
  def up
    create_table :pxe_menus do |t|
      t.string      :file_name
      t.text        :contents
      t.belongs_to  :pxe_server, :type => :bigint
      t.timestamps
    end
  end

  def down
    drop_table :pxe_menus
  end
end
