# coding: utf-8
class ContainerLabelTagMapping
  # Performs most of the work of ContainerLabelTagMapping - holds current mappings,
  # computes applicable tags, and creates/finds Tag records - except actually [un]assigning.
  class Mapper
    # @return [InventoryCollection<Tag>] a collection saving which will find/create (never delete) all
    #   tags referenced by #map_labels whose id is not yet known.
    attr_reader :tags_to_resolve_collection
    # @return [InventoryCollection<Tag>] represents tags whose id is already known.
    #   Doesn't require saving, not really interesting.
    attr_reader :specific_tags_collection

    # @param mappings [Array<ContainerLabelTagMapping>] Mapping records to use
    def initialize(mappings)
      # {[name, type, value] => [tag_id, ...]}
      @mappings = mappings.group_by { |m| [m.label_name, m.labeled_resource_type, m.label_value].freeze }
                          .transform_values { |ms| ms.collect(&:tag_id) }

      require "inventory_refresh"
      @tags_to_resolve_collection = ::InventoryRefresh::InventoryCollection.new(
        :name              => :mapped_tags_to_resolve,
        :model_class       => Tag,
        # more than needed to identify, doesn't matter much as we use custom save
        :manager_ref       => [:category_tag_id, :entry_name, :entry_description],
        #:arel            => Tag.all,
        :custom_save_block => lambda do |_ems, inv_collection|
          # TODO: O(N) queries, optimize.
          inv_collection.each do |inv_object|
            inv_object.id ||= find_or_create_tag(inv_object.attributes)
          end
        end
      )

      @specific_tags_collection = ::InventoryRefresh::InventoryCollection.new(
        :name        => :mapped_specific_tags,
        :model_class => Tag,
        :manager_ref => [:id],
      )
    end

    # Compute desired tags, in intermediate form to be resolved later.
    #
    # @param type [String] Matched against `labeled_resource_type` in mappings.
    #   May be `resource_type` of an actual label, but doesn't have to; can be fake string such as 'Vm'.
    # @param labels [Array] array of {:name, :value} hashes.
    # @return [Array<InventoryObject>] representing desired tags.
    def map_labels(type, labels)
      labels.collect_concat { |label| map_label(type, label) }.uniq
    end

    # Convert "tag references" to actual Tag objects.  Must have been resolved to known id first.
    # @param tag_references [Array<InventoryObject>]
    # @return [Array<Tag>]
    def self.references_to_tags(tag_references)
      ref_without_id = tag_references.detect { |ref| ref.id.nil? }
      raise "Unresolved tag reference #{ref_without_id}, must save tags_to_resolve_collection first" if ref_without_id

      Tag.find(tag_references.collect(&:id))
    end

    private

    def map_label(type, label)
      # Apply both specific-type and any-type, independently.
      (map_name_type_value(label[:name], type, label[:value]) +
       map_name_type_value(label[:name], nil,  label[:value]))
    end

    def map_name_type_value(name, type, value)
      specific_value = @mappings[[name, type, value]] || []
      any_value      = @mappings[[name, type, nil]]   || []
      if !specific_value.empty?
        specific_value.map { |tag_id| emit_specific_reference(tag_id) }
      else
        if value.empty?
          [] # Don't map empty value to any tag.
        else
          # Note: if the way we compute `entry_name` changes,
          # consider what will happen to previously created tags.
          any_value.map do |tag_id|
            emit_tag_reference(
              :category_tag_id   => tag_id,
              :entry_name        => Classification.sanitize_name(value),
              :entry_description => value,
            )
          end
        end
      end
    end

    def emit_tag_reference(h)
      tags_to_resolve_collection.find_or_build_by(h)
    end

    def emit_specific_reference(tag_id)
      inv_object = specific_tags_collection.find_or_build_by(:id => tag_id)
      inv_object.id = tag_id
      inv_object
    end

    # @return [Integer] Tag id
    # Mutate the hash to contain :tag_id.
    def find_or_create_tag(tag_hash)
      category = Tag.find(tag_hash[:category_tag_id]).classification
      entry = category.find_entry_by_name(tag_hash[:entry_name])
      unless entry
        category.lock(:exclusive) do
          begin
            entry = category.add_entry(:name        => tag_hash[:entry_name],
                                       :description => tag_hash[:entry_description])
            entry.save!
          rescue ActiveRecord::RecordInvalid
            entry = category.find_entry_by_name(tag_hash[:entry_name])
          end
        end
      end
      entry.tag_id
    end
  end
end
