class AddInitiatorToService < ActiveRecord::Migration[5.0]
  class Service < ActiveRecord::Base; end
  def up
    add_column :services, :initiator, :string
    change_column_comment :services, :initiator, "Record who initiated the service creation user|control|alert. It helps the UI display the services based on categories"
    say_with_time('Adding initiator to Service') do
      Service.update_all(:initiator => 'user')
    end
  end

  def down
    remove_column :services, :initiator
  end
end
