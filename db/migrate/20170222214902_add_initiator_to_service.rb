class AddInitiatorToService < ActiveRecord::Migration[5.0]
  class Service < ActiveRecord::Base; end
  def up
    add_column :services, :initiator, :string, :comment => "Entity that initiated the service creation"
    say_with_time("Updating existing services to 'user' initiator") do
      Service.update_all(:initiator => 'user')
    end
  end

  def down
    remove_column :services, :initiator
  end
end
