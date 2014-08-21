class IsoImage < ActiveRecord::Base
  belongs_to :iso_datastore
  belongs_to :pxe_image_type
  belongs_to :storage

  has_many :customization_templates, :through => :pxe_image_type
end
