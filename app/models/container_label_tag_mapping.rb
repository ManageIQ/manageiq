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

  scope :any_value,      -> { where(:label_value => nil) }
  scope :specific_value, -> { where.not(:label_value => nil) }

  require_nested :Mapper

  # Return ContainerLabelTagMapping::Mapper instance that holds all current mappings,
  # can compute applicable tags, and create/find Tag records.
  def self.mapper
    ContainerLabelTagMapping::Mapper.new(in_my_region.all)
  end

  # Assigning/unassigning should be possible without Mapper instance, perhaps in another process.

  # Checks whether a Tag record is under mapping control. TODO: Remove? Only used by tests.
  def self.controls_tag?(tag)
    Tag.controlled_by_mapping.where(:id => tag.id).exists?
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
  end
end
