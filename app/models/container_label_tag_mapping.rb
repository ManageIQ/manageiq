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
  #   We then also add a specific `label_value`->specific `tag` mapping here.

  belongs_to :tag

  def self.drop_cache
    @hash_all_by_name_type_value = nil
    @mappable_tags = nil
  end

  # All tags that can be assigned by this mapping.
  def self.mappable_tags
    @mappable_tags ||= Tag.joins(:container_label_tag_mappings).where.not(
      :container_label_tag_mappings => {:label_value => nil}
    ).to_a
  end

  # Returns {[name, type, value] => [tag, ...]}}} hash.
  def self.hash_all_by_name_type_value
    unless @hash_all_by_name_type_value
      @hash_all_by_name_type_value = {}
      includes(:tag).find_each { |m| load_mapping_into_hash(m, @hash_all_by_name_type_value) }
    end
    @hash_all_by_name_type_value
  end

  def self.load_mapping_into_hash(mapping, hash)
    key = [mapping.label_name, mapping.labeled_resource_type, mapping.label_value].freeze
    hash[key] ||= []
    hash[key] << mapping.tag
  end
  private_class_method :load_mapping_into_hash

  # Main entry point
  def self.tags_for_entity(entity)
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
        create_specific_value_mapping(name, type, value, category_tag).tag
      end
    end
  end

  # If this is an open ended any-value mapping, finds or creates a
  # specific-value mapping to a specific tag.
  def self.create_specific_value_mapping(name, type, value, category_tag)
    new_tag = create_tag(category_tag, value)
    new_mapping = create!(:labeled_resource_type => type, :label_name => name, :label_value => value,
                          :tag => new_tag)
    load_mapping_into_hash(new_mapping, @hash_all_by_name_type_value) if @hash_all_by_name_type_value
    @mappable_tags << new_tag if @mappable_tags
    new_mapping
  end
  private_class_method :create_specific_value_mapping

  def self.create_tag(category_tag, value)
    entry_name = Classification.sanitize_name(value)
    category = category_tag.classification
    if category
      entry = category.add_entry(:name => entry_name, :description => value)
      entry.save!
      entry.tag
    else
      # Suboptimal: original (unsanitized) value is not recorded.
      Tag.create!(:name => File.join(category_tag.name, entry_name))
    end
  end
  private_class_method :create_tag
end
