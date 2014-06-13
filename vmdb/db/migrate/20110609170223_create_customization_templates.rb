class CreateCustomizationTemplates < ActiveRecord::Migration
  def self.up
    create_table :customization_templates do |t|
      t.string      :name
      t.string      :description
      t.text        :script
      t.timestamps
    end

    add_column    :pxe_servers, :access_url, :string
  end

  def self.down
    drop_table :customization_templates
    remove_column :pxe_servers, :access_url
  end
end
