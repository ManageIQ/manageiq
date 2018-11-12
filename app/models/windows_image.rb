class WindowsImage < ApplicationRecord
  belongs_to :pxe_server
  belongs_to :pxe_image_type

  has_many :customization_templates, :through => :pxe_image_type

  def self.display_name(number = 1)
    n_('Windows Image', 'Windows Images', number)
  end
end
