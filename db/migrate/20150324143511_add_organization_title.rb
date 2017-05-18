class AddOrganizationTitle < ActiveRecord::Migration[4.2]
  def change
    add_column :configuration_organizations, :title, :string
    add_column :configuration_locations, :title, :string
  end
end
