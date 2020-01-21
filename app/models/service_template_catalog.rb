class ServiceTemplateCatalog < ApplicationRecord
  include TenancyMixin
  validates_presence_of     :name
  validates :name, :uniqueness => {:scope => :tenant_id}

  belongs_to :tenant
  has_many  :service_templates, :dependent => :nullify

  acts_as_miq_taggable

  def self.display_name(number = 1)
    n_('Catalog', 'Catalogs', number)
  end
end
