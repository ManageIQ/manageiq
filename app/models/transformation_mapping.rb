class TransformationMapping < ApplicationRecord
  has_many :transformation_mapping_items, :dependent => :destroy
  has_many :service_resources, :as => :resource, :dependent => :nullify
  has_many :service_templates, :through => :service_resources

  validates :name, :presence => true, :uniqueness => true

  def destination(source)
    transformation_mapping_items.find_by(:source => source).try(:destination)
  end
end
