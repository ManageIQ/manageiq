class HostStorage < ApplicationRecord
  belongs_to :host
  belongs_to :storage

  include ReservedMixin

  reserve_attribute :ems_ref, :string
end
