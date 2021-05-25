class Tagging < ApplicationRecord
  belongs_to :tag
  belongs_to :taggable, :polymorphic => true

  # HACK: We need to do this to fake AR into doing STI so that polymorphic
  #       relationships to this class save the *_type column with the full
  #       sub-class's name as opposed to the base model class. This is needed
  #       so that tagging works properly. Once tagging is reworked to handle
  #       the base model class name this can be removed and real STI can be
  #       used.
  before_create do
    if self.taggable.kind_of? MiqSet
      self.taggable_type = self.taggable.class.name
    end
  end
end
