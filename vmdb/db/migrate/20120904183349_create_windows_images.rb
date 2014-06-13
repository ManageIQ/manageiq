class CreateWindowsImages < ActiveRecord::Migration
  def change
    create_table :windows_images do |t|
      t.string     :name
      t.string     :description
      t.string     :path
      t.integer    :index
      t.belongs_to :pxe_server
    end

    add_column :pxe_servers, :windows_images_directory, :string
  end
end
