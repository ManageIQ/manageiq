class WindowsImage < ActiveRecord::Base
  belongs_to :pxe_server
  belongs_to :pxe_image_type

  has_many :customization_templates, :through => :pxe_image_type
end
