class ServiceTemplateCatalog < ActiveRecord::Base
  include ReportableMixin
  validates_presence_of     :name
  validates_uniqueness_of   :name

  has_many  :service_templates, :dependent => :nullify
end
