# A mapping matches labels on `resource_type` (NULL means any), `name` (required),
# and `value` (NULL means any).
#
# Note: `labeled_resource_type` doesn't really need to match the actual label's `resource_type`;
# it's simply matched against the type argument to Mapper#map_labels,
# and sometimes is a fake string like 'Vm' or 'Image' instead of a model name.
#
# Different labels might map to same tag, and one label might map to multiple tags.
#
# There are 2 kinds of rows:
# - When `label_value` is specified, we map only this value to a specific `tag`.
#   TODO: drop this.  This was never exposed in UI and is dead code to maintain.
#
# - When `label_value` is NULL, we map this name with any value to per-value tags.
#   In this case, `tag` specifies the category under which to create
#   the value-specific tag (and classification) on demand.
#
# All involved tags must also have a Classification.
#
# TODO: rename, no longer specific to containers.
class ContainerLabelTagMapping < ApplicationRecord
  belongs_to :tag

  require_nested :Mapper

  TAG_PREFIXES = %w(amazon azure kubernetes openstack).map { |name| "/managed/#{name}:" }.freeze
  validate :validate_tag_prefix

  # Return ContainerLabelTagMapping::Mapper instance that holds all current mappings,
  # can compute applicable tags, and create/find Tag records.
  def self.mapper
    ContainerLabelTagMapping::Mapper.new(in_my_region.all)
  end

  # Assigning/unassigning should be possible without Mapper instance, perhaps in another process.

  # Checks whether a Tag record is under mapping control.
  # TODO: expensive.
  def self.controls_tag?(tag)
    return false unless tag.classification.try(:read_only) # never touch user-assignable tags.
    tag_ids = [tag.id, tag.category.tag_id].uniq
    where(:tag_id => tag_ids).any?
  end

  # Assign/unassign mapping-controlled tags, preserving user-assigned tags.
  # All tag references must have been resolved first by Mapper#find_or_create_tags.
  def self.retag_entity(entity, tag_references)
    mapped_tags = Mapper.references_to_tags(tag_references)
    existing_tags = entity.tags.controlled_by_mapping
    Tagging.transaction do
      (mapped_tags - existing_tags).each do |tag|
        Tagging.create!(:taggable => entity, :tag => tag)
      end
      (existing_tags - mapped_tags).tap do |tags|
        Tagging.where(:taggable => entity, :tag => tags.collect(&:id)).destroy_all
      end
    end
    entity.tags.reset
    entity.taggings.reset
  end

  def validate_tag_prefix
    unless TAG_PREFIXES.any? { |prefix| tag.name.start_with?(prefix) }
      errors.add(:tag_id, "tag category name #{tag.name} doesn't start with any of #{TAG_PREFIXES}")
    end
  end
end
