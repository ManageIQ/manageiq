class AddReportingColsToAuthentications < ActiveRecord::Migration
  def self.up
    add_column    :authentications, :last_valid_on,          :datetime
    add_column    :authentications, :last_invalid_on,        :datetime
    add_column    :authentications, :credentials_changed_on, :datetime
    add_column    :authentications, :status,                 :string
    add_column    :authentications, :status_details,         :string
  end

  def self.down
    remove_column :authentications, :last_valid_on
    remove_column :authentications, :last_invalid_on
    remove_column :authentications, :credentials_changed_on
    remove_column :authentications, :status
    remove_column :authentications, :status_details
  end
end
