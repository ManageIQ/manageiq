class AddEnabledFieldToEms < ActiveRecord::Migration[5.0]
  class ExtManagementSystem < ActiveRecord::Base; end

  def change
    add_column :ext_management_systems, :enabled, :boolean

    say_with_time('Setting ExtManagementSystem.enabled to true') do
      ExtManagementSystem.update_all(:enabled => true)
    end
  end
end
