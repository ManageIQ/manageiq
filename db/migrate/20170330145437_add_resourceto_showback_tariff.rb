class AddResourcetoShowbackTariff < ActiveRecord::Migration[5.0]
  def change
    add_belongs_to :showback_tariffs, :resource, :null =>  false, type: :bigint, :polymorphic => true
  end
end
