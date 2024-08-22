class NetworkServiceEntry < ApplicationRecord
  include NewWithTypeStiMixin
  include CloudTenancyMixin
  include CustomActionsMixin

  acts_as_miq_taggable

  belongs_to :ext_management_system, :foreign_key => :ems_id, :class_name => "ManageIQ::Providers::NetworkManager"
  belongs_to :network_service
  belongs_to :orchestration_stack
  has_many :network_service_entries, :foreign_key => :ems_id, :dependent => :destroy

  def self.class_by_ems(ext_management_system)
    ext_management_system&.class_by_ems(:NetworkServiceEntry)
  end
end
