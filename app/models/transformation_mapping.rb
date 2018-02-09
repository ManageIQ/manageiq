class TransformationMapping < ApplicationRecord
  has_many :transformation_mapping_items, :dependent => :destroy

  validates :name, :presence => true, :uniqueness => true

  def destination(source)
    transformation_mapping_items.find_by(:source => source).try(:destination)
  end
end
