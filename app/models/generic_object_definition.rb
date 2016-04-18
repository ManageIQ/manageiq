class GenericObjectDefinition < ApplicationRecord
  validates :name, :presence => true, :uniqueness => true

  serialize :properties, Hash

  has_one   :picture, :dependent => :destroy, :as => :resource
  has_many  :generic_objects

  def defined_attributes
    @defined_attributes ||= properties[:attributes].stringify_keys
  end
end
