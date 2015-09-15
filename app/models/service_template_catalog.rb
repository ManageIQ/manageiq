class ServiceTemplateCatalog < ActiveRecord::Base
  include ReportableMixin
  validates_presence_of     :name
  validates :name, :uniqueness => {:scope => :tenant_id}

  belongs_to :tenant
  has_many  :service_templates, :dependent => :nullify
end
