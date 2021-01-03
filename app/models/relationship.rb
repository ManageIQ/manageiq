require 'ancestry'

class Relationship < ApplicationRecord
  has_ancestry

  belongs_to :resource, :polymorphic => true

  scope :in_relationship, ->(rel) { where({:relationship => rel}) }

  #
  # Filtering methods
  #

  def self.filtered(of_type, except_type)
    relationships = self
    relationships = relationships.where(:resource_type => of_type) if of_type.present?
    relationships = relationships.where.not(:resource_type => except_type) if except_type.present?
    relationships
  end

  def filtered?(of_type, except_type)
    (!of_type.empty? && !of_type.include?(resource_type)) ||
      (!except_type.empty? && except_type.include?(resource_type))
  end

  def self.filter_by_resource_type(relationships, options)
    of_type = Array.wrap(options[:of_type])
    except_type = Array.wrap(options[:except_type])
    return relationships if of_type.empty? && except_type.empty?
    if relationships.kind_of?(Array) || relationships.try(:loaded?)
      relationships.reject { |r| r.filtered?(of_type, except_type) }
    else
      relationships.filtered(of_type, except_type)
    end
  end

  #
  # Resource methods
  #

  def self.resource(relationship)
    relationship.try!(:resource)
  end

  def self.resources(relationships)
    MiqPreloader.preload(relationships, :resource)
    relationships.collect(&:resource).compact
  end

  def self.resource_pair(relationship)
    relationship.try(:resource_pair)
  end

  def self.resource_pairs(relationships)
    relationships.collect(&:resource_pair)
  end

  def self.resource_ids(relationships)
    relationships.collect(&:resource_id)
  end

  def self.resource_types(relationships)
    relationships.collect(&:resource_type).uniq
  end

  def self.resource_pairs_to_ids(resource_pairs)
    resource_pairs.empty? ? resource_pairs : resource_pairs.transpose.last
  end

  def resource_pair
    [resource_type, resource_id]
  end

  #
  # Arranging methods
  #

  def self.flatten_arranged_rels(relationships)
    result             = relationships.keys
    remaining_children = relationships.values
    until remaining_children.empty?
      remaining_children.pop.each do |rel, kids|
        result << rel
        remaining_children << kids
      end
    end
    result
  end

  def self.arranged_rels_to_resources(relationships, initial = true)
    MiqPreloader.preload(flatten_arranged_rels(relationships), :resource) if initial

    relationships.each_with_object({}) do |(rel, children), h|
      h[rel.resource] = arranged_rels_to_resources(children, false)
    end
  end

  def self.arranged_rels_to_resource_pairs(relationships)
    relationships.each_with_object({}) do |(rel, children), h|
      h[rel.resource_pair] = arranged_rels_to_resource_pairs(children)
    end
  end

  # This prunes a tree already in memory
  # may be faster to prune the tree before creating the tree
  def self.filter_arranged_rels_by_resource_type(relationships, options)
    of_type = Array.wrap(options[:of_type].presence)
    except_type = Array.wrap(options[:except_type].presence)
    return relationships if of_type.empty? && except_type.empty?

    relationships.each_with_object({}) do |(rel, children), h|
      if !rel.filtered?(of_type, except_type)
        h[rel] = filter_arranged_rels_by_resource_type(children, options)
      elsif h.empty?
        # Special case where we want something filtered, but some nodes
        #   from the root down must be skipped first.
        h.merge!(filter_arranged_rels_by_resource_type(children, options))
      end
    end
  end

  def self.puts_arranged_resources(subtree, indent = '')
    subtree = subtree.sort_by do |obj, _children|
      name = obj.send([:name, :description, :object_id].detect { |m| obj.respond_to?(m) })
      [obj.class.name.downcase, name.downcase]
    end
    subtree.each do |obj, children|
      name = obj.send([:name, :description, :object_id].detect { |m| obj.respond_to?(m) })
      puts "#{indent}- #{obj.class.name} #{obj.id}: #{name}"
      puts_arranged_resources(children, "  #{indent}")
    end
  end

  #
  # Other methods
  #

  # Returns a String form of the relationships passed
  #   Accepts the following options:
  #     :field_delimiter  - defaults to ':'
  #     :record_delimiter - defaults to '/'
  #     :exclude_class    - defaults to false
  #     :field_method     - defaults to :id
  def self.stringify_rels(rels, options = {})
    options.reverse_merge!(
      :field_delimiter  => ':',
      :record_delimiter => '/',
      :exclude_class    => false,
      :field_method     => :id
    )

    fields = rels.collect do |obj|
      field = obj.send(options[:field_method])
      options[:exclude_class] ? field : [obj.class.base_class.name, field].join(options[:field_delimiter])
    end
    fields.join(options[:record_delimiter])
  end

  # Returns a String form of the class/id pairs passed
  #   Accepts the following options:
  #     :field_delimiter  - defaults to ':'
  #     :record_delimiter - defaults to '/'
  #     :exclude_class    - defaults to false
  def self.stringify_resource_pairs(resource_pairs, options = {})
    options.reverse_merge!(
      :field_delimiter  => ':',
      :record_delimiter => '/',
      :exclude_class    => false
    )

    fields = resource_pairs.collect do |pair|
      options[:exclude_class] ? pair.last : pair.join(options[:field_delimiter])
    end
    fields.join(options[:record_delimiter])
  end

  # ancestry methods

  # depth = depth + 2 ()
  #
  # ancestry:
  #   my children:              ancestry == me.child_ancestry
  #   my grand children:        ancestry == "#{me.child_ancestry}/[0-9]*"
  #   my great grand children:  ancestry == "#{me.child_ancestry}/[0-9]*/[0-9]*"
  #
  # regexp was simpler but 10x slower. so used like
  #
  # algorithm:
  #
  #       (relationship LIKE "child_ancestry/%"             -- grand child or lower
  #       AND NOT relationship LIKE "child_ancestry/%/%")   -- NOT great grand child or lower
  #
  # reminders:
  # - matches("a%", nil, true) is case sensitive matching (i.e.: "like 'a%'") vs default (i.e.: "ilike 'a%'")
  #
  def grandchildren
    t = self.class.arel_table
    self.class.where(t[:ancestry].matches("#{child_ancestry}/%", nil, true))
        .where(t[:ancestry].does_not_match("#{child_ancestry}/%/%", nil, true))
  end

  def child_and_grandchildren
    grandchildren.or(children)
  end
end
