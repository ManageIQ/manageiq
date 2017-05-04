class AddApplicationInstallTime < ActiveRecord::Migration[4.2]
  def change
    add_column :guest_applications, :install_time, :timestamp
  end
end
