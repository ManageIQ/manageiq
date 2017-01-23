class ServiceTemplateCatalog < ApplicationRecord
  include TenancyMixin
  validates_presence_of     :name
  validates :name, :uniqueness => {:scope => :tenant_id}

  belongs_to :tenant
  has_many  :service_templates, :dependent => :nullify

  acts_as_miq_taggable
end
