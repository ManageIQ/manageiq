class AddOrganizationTitle < ActiveRecord::Migration
  def change
    add_column :configuration_organizations, :title, :string
    add_column :configuration_locations, :title, :string
  end
end
