class ServiceTemplateCatalog < ActiveRecord::Base
  include ReportableMixin
  include TenancyMixin
  validates :name, :uniqueness => {:scope => :tenant_id}, :presence => true
  validates :tenant_id, :presence => true

  belongs_to :tenant
  has_many  :service_templates, :dependent => :nullify
end
