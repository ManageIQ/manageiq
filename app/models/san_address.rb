class SanAddress < ApplicationRecord
  include ProviderObjectMixin
  include NewWithTypeStiMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id
  belongs_to :owner, :polymorphic => true

  acts_as_miq_taggable

  def address_value
    raise NotImplementedError, _("must be implemented in subclass")
  end
end
