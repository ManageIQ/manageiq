class ServiceTemplateCatalog < ApplicationRecord
  include TenancyMixin
  validates :name, :presence => true, :uniqueness_when_changed => {:scope => :tenant_id}

  belongs_to :tenant
  has_many  :service_templates, :dependent => :nullify

  acts_as_miq_taggable

  def self.display_name(number = 1)
    n_('Catalog', 'Catalogs', number)
  end
end
