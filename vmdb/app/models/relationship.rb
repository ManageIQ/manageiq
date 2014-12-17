require 'ancestry'

class Relationship < ActiveRecord::Base
  has_ancestry

  belongs_to :resource, :polymorphic => true

  scope :in_relationship, lambda { |rel| {:conditions => {:relationship => rel}} }

  #
  # Filtering methods
  #

  def filtered?(of_type, except_type)
    (!of_type.empty? && !of_type.include?(self.resource_type)) ||
      (!except_type.empty? && except_type.include?(self.resource_type))
  end

  def self.filter_by_resource_type(relationships, options)
    of_type = options[:of_type].to_miq_a
    except_type = options[:except_type].to_miq_a
    return relationships if of_type.empty? && except_type.empty?
    return relationships.reject { |r| r.filtered?(of_type, except_type) }
  end

  #
  # Resource methods
  #

  def self.resource(relationship)
    relationship.nil? ? nil : relationship.resource
  end

  def self.resources(relationships)
    MiqPreloader.preload(relationships, :resource)
    relationships.collect { |r| r.resource }
  end

  def self.resource_pair(relationship)
    relationship.nil? ? nil : relationship.resource_pair
  end

  def self.resource_pairs(relationships)
    relationships.collect { |r| r.resource_pair }
  end

  def self.resource_ids(relationships)
    relationships.collect { |r| r.resource_id }
  end

  def self.resource_types(relationships)
    relationships.collect { |r| r.resource_type }.uniq
  end

  def self.resource_pairs_to_ids(resource_pairs)
    resource_pairs.empty? ? resource_pairs : resource_pairs.transpose.last
  end

  def resource_pair
    return [self.resource_type, self.resource_id]
  end

  #
  # Arranging methods
  #

  def self.flatten_arranged_rels(relationships)
    relationships.each_with_object([]) do |(rel, children), a|
      a << rel
      a.concat(self.flatten_arranged_rels(children))
    end
  end

  def self.arranged_rels_to_resources(relationships, initial = true)
    MiqPreloader.preload(self.flatten_arranged_rels(relationships), :resource) if initial

    relationships.each_with_object({}) do |(rel, children), h|
      h[rel.resource] = self.arranged_rels_to_resources(children, false)
    end
  end

  def self.arranged_rels_to_resource_pairs(relationships)
    relationships.each_with_object({}) do |(rel, children), h|
      h[rel.resource_pair] = self.arranged_rels_to_resource_pairs(children)
    end
  end

  def self.filter_arranged_rels_by_resource_type(relationships, options)
    of_type = options[:of_type].to_miq_a
    except_type = options[:except_type].to_miq_a
    return relationships if of_type.empty? && except_type.empty?

    relationships.each_with_object({}) do |(rel, children), h|
      if !rel.filtered?(of_type, except_type)
        h[rel] = self.filter_arranged_rels_by_resource_type(children, options)
      elsif h.empty?
        # Special case where we want something filtered, but some nodes
        #   from the root down must be skipped first.
        h.merge!(self.filter_arranged_rels_by_resource_type(children, options))
      end
    end
  end

  def self.puts_arranged_resources(subtree, indent = '')
    subtree = subtree.sort_by do |obj, children|
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
    return fields.join(options[:record_delimiter])
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
    return fields.join(options[:record_delimiter])
  end

  #
  # Backward compatibility methods
  #

  # Gets the entire tree in as few queries as possible, though it may end up
  #   pulling back many more objects than necessary.
  #   NOTE: Will only populate .children cache.
  def self.get_tree(root, rel_type = nil, options = {})
    deprecate_method("get_tree", "subtree_arranged or descendants_arranged")
    return if root.nil?

    # Build a tree of children manually, starting at the root
    descendants = root.with_relationship_type(rel_type) { root.descendants_arranged(options) }
    build_tree(root, descendants)
  end

#  def self.get_rels_by_parent(relationship_type, options = {})
#    excluded_types = options[:excluded_types].to_miq_a
#    included_types = options[:included_types].to_miq_a
#    options[:include] = :child unless options.has_key?(:include)
#
#    cond = ["relationship = ?", relationship_type]
#    unless excluded_types.empty?
#      cond[0] << " AND child_type NOT IN (?)"
#      cond << excluded_types
#    end
#
#    unless included_types.empty?
#      cond[0] << " AND child_type IN (?)"
#      cond << included_types
#    end
#
#    cols = self.column_names - ["created_on", "updated_on", "reserved"]
#    rels = Relationship.all(:conditions => cond, :include => options[:include], :select => cols.join(","))
#
#    rels.group_by { |r| [r.parent_type, r.parent_id] }
#  end

  def self.tree_to_a(node, oftype)
    deprecate_method("tree_to_a", "subtree or descendants")
    node.subtree(:of_type => oftype)
  end

  # Recursive helper method for get_tree
  def self.build_tree(root, descendants)
    child_objs = descendants.collect { |obj, children| build_tree(obj, children) }
    root.instance_variable_set(:@_memoized_children, {[] => child_objs})
    return root
  end
  private_class_method :build_tree

  def self.deprecate_method(method, instead)
    unless Rails.env.production?
      msg = "[DEPRECATION] #{method} method is deprecated.  Please use #{instead} instead.  At #{caller[1]}"
      $log.warn msg
      warn msg
    end
  end
  private_class_method :deprecate_method
end
