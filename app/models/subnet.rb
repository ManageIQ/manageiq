class Subnet < ApplicationRecord
  include NewWithTypeStiMixin

  acts_as_miq_taggable

  belongs_to :lan
end

DescendantLoader.instance.load_subclasses(Subnet)
