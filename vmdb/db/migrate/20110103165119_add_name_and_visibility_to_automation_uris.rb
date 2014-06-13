class AddNameAndVisibilityToAutomationUris < ActiveRecord::Migration
  def self.up
    add_column    :automation_uris, :name,        :string
    add_column    :automation_uris, :visibility,  :text
  end

  def self.down
    remove_column :automation_uris, :name
    remove_column :automation_uris, :visibility
  end
end
