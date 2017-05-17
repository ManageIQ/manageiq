class ComputerSystem < ApplicationRecord
  belongs_to :managed_entity, :polymorphic => true
  # https://stackoverflow.com/questions/21850995/association-for-polymorphic-belongs-to-of-a-particular-type
  belongs_to :container_node, -> { where('computer_systems.managed_entity_type' => 'ContainerNode') }, :foreign_key => :managed_entity_id

  has_one :operating_system, :dependent => :destroy
  has_one :hardware, :dependent => :destroy
end
