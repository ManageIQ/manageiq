class FixServiceOrderPlacedAt < ActiveRecord::Migration[5.0]
  class ServiceOrder < ActiveRecord::Base; end

  def up
    say_with_time('Update placed_at in ordered ServiceOrders') do
      ServiceOrder.where(:state => 'ordered', :placed_at => nil).update_all('placed_at = updated_at')
    end
  end
end
