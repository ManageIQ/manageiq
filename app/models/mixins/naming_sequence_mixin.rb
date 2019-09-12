module NamingSequenceMixin
  extend ActiveSupport::Concern

  included do
    # these are possible naming sequences because there is no constraint to source column
    has_many :naming_sequences, :as => :resource, :dependent => :destroy, :class_name => "CustomAttribute"
  end

  def next_naming_sequence(name, source)
    lock do
      record = naming_sequences.where(:name => name, :source => source).first_or_initialize
      record.update!(:value => record.value.to_i + 1)

      record.value.to_i
    end
  end
end
