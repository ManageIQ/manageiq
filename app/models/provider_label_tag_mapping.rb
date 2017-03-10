class ProviderLabelTagMapping < ApplicationRecord
  belongs_to :tag
  belongs_to :mappable_entity

  # Shortcut for self.mappable_entity.name. Provided for backwards compatibility.
  #
  def labeled_resource_type
    mappable_entity.name
  end

  # Shortcut for self.mappable_entity.name=. Provided for backwards compatibility.
  #
  def labeled_resource_type=(value)
    mappable_entity.name = value
  end

  # Return a flat list of mappable entity names. The nil is required by the
  # user interface drop down menu for "all".
  #
  def self.mappable_entities(provider = 'kubernetes')
    MappableEntity.where(:provider => provider).pluck(:name).sort.unshift(nil)
  end

  # Returns a hash of mappings, with the mapping object (in array form) as the
  # key, and its tag_id as the value. This hash should be passed to the various
  # map_xxx methods.
  #
  # Example Output:
  #
  # {
  #   ["kubernetes", "foo label", nil, nil]=>[128],
  #   ["kubernetes", "other label", "ContainerNode", nil]=>[129]
  # }
  #
  # The first array key has no model type, so it applies to everything. The
  # second array key applies only to the ContainerNode type. Both apply only
  # to the Kubernetes provider. Neither value has a label_value set.
  #
  # The value for each array key is the underlying record's tag_id.
  #
  def self.cache
    # {[name, type, value] => [tag_id, ...]} - see lib/extensions/ar_region.rb
    in_my_region.find_each
                .group_by { |m| [m.label_name, m.labeled_resource_type, m.label_value].freeze }
                .transform_values { |mappings| mappings.collect(&:tag_id) }
  end

  # We expect labels to be {:name, :value} hashes
  # and return {:tag_id} or {:category_tag_id, :entry_name, :entry_description} hashes.

  def self.map_labels(cache, type, labels)
    labels.collect_concat { |label| map_label(cache, type, label) }.uniq
  end

  def self.map_label(cache, type, label)
    # Apply both specific-type and any-type, independently.
    (map_name_type_value(cache, label[:name], type, label[:value]) +
     map_name_type_value(cache, label[:name], nil,  label[:value]))
  end

  def self.map_name_type_value(cache, name, type, value)
    specific_value = cache[[name, type, value]] || []
    any_value      = cache[[name, type, nil]]   || []
    if !specific_value.empty?
      specific_value.map { |tag_id| {:tag_id => tag_id} }
    else
      if value.empty?
        [] # Don't map empty value to any tag.
      else
        # Note: if the way we compute `entry_name` changes,
        # consider what will happen to previously created tags.
        any_value.map do |tag_id|
          {:category_tag_id   => tag_id,
           :entry_name        => Classification.sanitize_name(value),
           :entry_description => value}
        end
      end
    end
  end
  private_class_method :map_name_type_value

  # Given a hash built by `map_*` methods, returns a Tag (creating if needed).
  def self.find_or_create_tag(tag_hash)
    if tag_hash[:tag_id]
      Tag.find(tag_hash[:tag_id])
    else
      category = Tag.find(tag_hash[:category_tag_id]).classification
      entry = category.find_entry_by_name(tag_hash[:entry_name])
      unless entry
        category.lock :exclusive do
          begin
            entry = category.add_entry(:name        => tag_hash[:entry_name],
                                       :description => tag_hash[:entry_description])
            entry.save!
          rescue ActiveRecord::RecordInvalid
            entry = category.find_entry_by_name(tag_hash[:entry_name])
          end
        end
      end
      entry.tag
    end
  end

  def self.controls_tag?(tag)
    return false unless tag.classification.try(:read_only) # never touch user-assignable tags.
    tag_ids = [tag.id, tag.category.tag_id].uniq
    where(:tag_id => tag_ids).any?
  end

  # Assign/unassign mapping-controlled tags, preserving user-assigned tags.
  def self.retag_entity(entity, tag_hashes)
    mapped_tags = tag_hashes.map { |tag_hash| find_or_create_tag(tag_hash) }
    existing_tags = entity.tags
    Tagging.transaction do
      (mapped_tags - existing_tags).each do |tag|
        Tagging.create!(:taggable => entity, :tag => tag)
      end
      (existing_tags - mapped_tags).select { |tag| controls_tag?(tag) }.tap do |tags|
        Tagging.where(:taggable => entity, :tag => tags.collect(&:id)).destroy_all
      end
    end
    entity.tags.reset
  end
end
