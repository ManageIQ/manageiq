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

  def self.drop_cache
    @hash_all_by_name_type_value = nil
  end

  # Returns {[name, type, value] => [tag, ...]}}} hash.
  def self.hash_all_by_name_type_value
    unless @hash_all_by_name_type_value
      @hash_all_by_name_type_value = {}
      includes(:tag).find_each { |m| load_mapping_into_hash(m) }
    end
    @hash_all_by_name_type_value
  end

  def self.load_mapping_into_hash(mapping)
    return unless @hash_all_by_name_type_value
    key = [mapping.label_name, mapping.labeled_resource_type, mapping.label_value].freeze
    @hash_all_by_name_type_value[key] ||= []
    @hash_all_by_name_type_value[key] << mapping.tag
  end
  private_class_method :load_mapping_into_hash

  def self.tags_for_entity(entity, labels = entity.labels)
    entity.labels.collect_concat { |label| tags_for_label(label) }
  end

  def self.tags_for_label(label)
    # Apply both specific-type and any-type, independently.
    (tags_for_name_type_value(label.name, label.resource_type, label.value) +
     tags_for_name_type_value(label.name, nil,                 label.value))
  end

  def self.tags_for_name_type_value(name, type, value)
    specific_value = hash_all_by_name_type_value[[name, type, value]] || []
    any_value      = hash_all_by_name_type_value[[name, type, nil]]   || []
    if !specific_value.empty?
      specific_value
    else
      any_value.map do |category_tag|
        specific_value_tag(name, value, category_tag)
      end
    end
  end
  private_class_method :tags_for_name_type_value

  # If this is an open ended any-value mapping, finds or creates a
  # specific-value mapping to a specific tag.
  def self.specific_value_tag(name, value, category_tag)
    category = category_tag.classification

    # Note: the names chosen here should remain stable,
    # or we won't be able to find previously created tags.
    if value.empty?
      entry_name = ':empty:' # ':' character won't occur in kubernetes values.
      description = '<empty value>'
    else
      entry_name = Classification.sanitize_name(value)
      description = value
    end

    entry = category.find_entry_by_name(entry_name)
    unless entry
      entry = category.add_entry(:name => entry_name, :description => description)
      entry.save!  # TODO can this error?
    end
    entry.tag
  end
  private_class_method :specific_value_tag

  def self.controls_tag?(tag)
    return false unless tag.classification.try(:read_only) # never touch user-assignable tags.
    tag_ids = [tag.id, tag.category.tag_id].uniq
    where(:tag_id => tag_ids).any?
  end

  # Assign/unassign mapping-controlled tags, preserving user-assigned tags.
  def self.retag_entity(entity, labels = entity.labels)
    mapped_tags = tags_for_entity(entity, labels)
    existing_tags = entity.tags
    tags_to_unassign = (existing_tags - mapped_tags).select { |t| controls_tag?(t) }
    entity.tags = (existing_tags | mapped_tags) - tags_to_unassign
  end
end
