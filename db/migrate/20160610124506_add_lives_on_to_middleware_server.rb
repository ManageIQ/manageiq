class AddLivesOnToMiddlewareServer < ActiveRecord::Migration[5.0]
  def change
    add_reference :middleware_servers, :lives_on, :type => :bigint, :polymorphic => true
  end
end
