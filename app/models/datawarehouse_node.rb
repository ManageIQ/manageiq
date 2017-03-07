class DatawarehouseNode < ApplicationRecord
  include CustomAttributeMixin

  belongs_to :ext_management_system, :foreign_key => "ems_id"

  belongs_to :lives_on, :polymorphic => true

  acts_as_miq_taggable
end
