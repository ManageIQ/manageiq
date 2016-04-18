class AddCrossManagerAssociationToConfiguredSystem < ActiveRecord::Migration[5.0]
  def change
    add_reference(:configured_systems, :counterpart, :polymorphic => true, :type => :bigint)
  end
end
