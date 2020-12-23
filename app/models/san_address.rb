class SanAddress < ApplicationRecord
  include ProviderObjectMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id
  belongs_to :owner, :polymorphic => true

  acts_as_miq_taggable

  def get_address_info
    raise NotImplementedError, _("must be implemented in subclass")
  end
end
