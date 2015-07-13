class AddApplicationInstallTime < ActiveRecord::Migration
  def change
    add_column :guest_applications, :install_time, :timestamp
  end
end
