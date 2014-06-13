class CreateServiceTemplateCatalog < ActiveRecord::Migration
  def up
    create_table :service_template_catalogs do |t|
      t.string     :name
      t.string     :description
    end

    change_table :service_templates do |t|
      t.belongs_to :service_template_catalog
    end

    remove_column :custom_buttons, :button_id
    remove_column :services,       :service_type
  end

  def down
    drop_table :service_template_catalogs
    change_table :service_templates do |t|
      t.remove_belongs_to :service_template_catalog
    end

    add_column :custom_buttons, :button_id,      :bigint
    add_column :services,       :service_type,   :string
  end
end
