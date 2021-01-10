class HostInitiator < ApplicationRecord
  include ProviderObjectMixin
  include SupportsFeatureMixin
  include CustomActionsMixin

  belongs_to :ext_management_system, :foreign_key => :ems_id
  belongs_to :physical_storage, :inverse_of => :host_initiators

  has_many :san_addresses, :as => :owner, :dependent => :destroy

  virtual_total :v_total_addresses, :san_addresses
end
