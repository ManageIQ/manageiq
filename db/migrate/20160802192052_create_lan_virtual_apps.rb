class CreateLanVirtualApps < ActiveRecord::Migration[5.0]
  def change
    create_table :lan_virtual_apps do |t|
      t.belongs_to :lan, :index => true
      t.belongs_to :virtual_app, :index => true
    end
  end
end
