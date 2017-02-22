class AddInitiatorToService < ActiveRecord::Migration[5.0]
  class Service < ActiveRecord::Base; end
  def up
    add_column :services, :initiator, :string
    say_with_time('Adding initiator to Service') do
      Service.all.each do |svc|
        svc.update_attributes!(:initiator => 'user')
      end
    end
  end

  def down
    remove_column :services, :initiator
  end
end
