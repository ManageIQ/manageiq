class ServiceTemplateCatalog < ActiveRecord::Base
  include ReportableMixin
  include TenancyMixin
  validates_presence_of     :name
  validates :name, :uniqueness => {:scope => :tenant_id}

  belongs_to :tenant
  has_many  :service_templates, :dependent => :nullify
end
