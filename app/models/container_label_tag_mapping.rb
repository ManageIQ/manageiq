class ContainerLabelTagMapping < ApplicationRecord
  # A mapping matches labels on `resource_type` (NULL means any), `name` (required),
  # and `value` (NULL means any).
  #
  # Different labels might map to same tag, and one label might map to multiple tags.
  #
  # There are 2 kinds of rows:
  # - When `label_value` is specified, we map only this value to a specific `tag`.
  # - When `label_value` is NULL, we map this name with any value to per-value tags.
  #   In this case, `tag` specifies the category under which to create
  #   the value-specific tag (and classification) on demand.
  #
  # All involved tags must also have a Classification.

  belongs_to :tag

  # Pass the data this returns to map_* methods.
  def self.cache
    # {[name, type, value] => [tag_id, ...]}
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
