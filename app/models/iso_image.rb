class IsoImage < ApplicationRecord
  belongs_to :iso_datastore
  belongs_to :pxe_image_type

  has_many :customization_templates, :through => :pxe_image_type
end
