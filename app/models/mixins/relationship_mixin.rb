require 'memoist'

module RelationshipMixin
  extend ActiveSupport::Concern

  MEMOIZED_METHODS = [
    :relationships_of,
    :parents,              :parent_rels,
    :root,                 :root_rel,
    :ancestors,            :ancestor_rels,
    :path,                 :path_rels,
    :siblings,             :sibling_rels,
    :has_siblings?,        :is_only_child?,
    :children,             :child_rels,
    :has_children?,        :is_childless?,
    :descendants,          :descendant_rels,
    :descendants_arranged, :descendant_rels_arranged,
    :subtree,              :subtree_rels,
    :subtree_arranged,     :subtree_rels_arranged,
    :fulltree,             :fulltree_rels,
    :fulltree_arranged,    :fulltree_rels_arranged,
    :parent_rel_ids,
  ]

  included do
    extend Memoist

    cattr_accessor :default_relationship_type

    has_many :all_relationships, :class_name => "Relationship", :dependent => :destroy, :as => :resource

    memoize(*MEMOIZED_METHODS)
  end

  module ClassMethods
    def alias_with_relationship_type(m_new, m_old, rel_type = nil)
      define_method(m_new) do |*args|
        with_relationship_type(rel_type || default_relationship_type) { send(m_old, *args) }
      end
    end
  end

  def reload(*args)
    clear_relationships_cache
    super
  end

  # only used from specs
  def clear_relationships_cache(*args)
    options = args.extract_options!
    to_clear = RelationshipMixin::MEMOIZED_METHODS - Array.wrap(options[:except])
    flush_cache(*to_clear) unless to_clear.empty?

    @association_cache.delete(:all_relationships)
  end

  #
  # relationship_type scoping methods
  #

  def relationship_types
    @relationship_types ||= []
  end

  def relationship_type
    relationship_types.blank? ? default_relationship_type : relationship_types.last
  end

  def relationship_type=(rel)
    unless relationship_type == rel
      relationship_types.push(rel)
      clear_relationships_cache(:except => :relationships_of)
    end
    rel
  end

  def with_relationship_type(rel)
    raise _("no block given") unless block_given?

    rel_changed = rel && (relationship_type != rel)
    self.relationship_type = rel unless rel.nil?

    begin
      yield(self)
    ensure
      if rel_changed
        relationship_types.pop
        clear_relationships_cache(:except => :relationships_of)
      end
    end
  end

  def relationships_of(rel_type)
    if @association_cache.include?(:all_relationships)
      all_relationships.select { |r| r.relationship == rel_type }
    else
      all_relationships.in_relationship(rel_type)
    end
  end

  def relationships
    relationships_of(relationship_type)
  end

  def relationship_ids
    relationships.collect(&:id)
  end

  #
  # has_ancestry methods
  #

  # Returns the id in the relationship table for this record's parents
  # from this id, relationship records can be brought back and mapped to the resource of interest
  # NOTE: parent_id is read from ancestry field, while parent is a db hit (N+1)
  # NOTE: relationships can be an array (from all_relationships cache) - so handle both Array and association
  def parent_rel_ids
    rel = relationships
    if rel.kind_of?(Array) || rel.try(:loaded?)
      rel.reject { |x| x.ancestry.blank? }.collect(&:parent_id)
    else
      rel.where.not(:ancestry => [nil, ""]).select(:ancestry).collect(&:parent_id)
    end
  end

  # Returns all of the relationships of the parents of the record, [] for a root node
  def parent_rels(*args)
    options = args.extract_options!
    pri = parent_rel_ids
    rels = pri.kind_of?(Array) && pri.empty? ? Relationship.none : Relationship.where(:id => pri)
    Relationship.filter_by_resource_type(rels, options)
  end

  # Returns all of the parents of the record, [] for a root node
  def parents(*args)
    Relationship.resources(parent_rels(*args))
  end

  # Returns all of the class/id pairs of the parents of the record, [] for a root node
  def parent_ids(*args)
    Relationship.resource_pairs(parent_rels(*args))
  end

  # Returns the number of parents of the record
  def parent_count(*args)
    parent_rels(*args).size
  end

  # Returns the relationship of the parent of the record, nil for a root node
  def parent_rel(*args)
    rels = parent_rels(*args).take(2)
    raise _("Multiple parents found.") if rels.length > 1
    rels.first
  end

  # Returns the parent of the record, nil for a root node
  def parent(*args)
    rels = parent_rels(*args).take(2)
    raise _("Multiple parents found.") if rels.length > 1
    rels.first.try(:resource)
  end

  # Returns the class/id pair of the parent of the record, nil for a root node
  def parent_id(*args)
    rels = parent_ids(*args).take(2)
    raise _("Multiple parents found.") if rels.length > 1
    rels.first
  end

  # Returns the relationship of the root of the tree the record is in
  def root_rel
    rel = relationship.try!(:root)
    # micro-optimization: if the relationship is us, "load" the resource
    rel.resource = self if rel && rel.resource_id == id && rel.resource_type == self.class.base_class.name.to_s
    rel || relationship_for_isolated_root
  end

  # Returns the root of the tree the record is in, self for a root node
  def root(*args)
    Relationship.resource(root_rel(*args))
  end

  # Returns the id of the root of the tree the record is in
  def root_id(*args)
    Relationship.resource_pair(root_rel(*args))
  end

  # Returns true if the record is a root node, false otherwise
  def is_root?
    rel = relationship # TODO: Handle a node that is a root and a node at the same time
    rel.nil? ? true : rel.is_root?
  end

  # Returns a relationship for a record that is a root node with no corresponding
  #   relationship record, meaning it is an isolated root node
  def relationship_for_isolated_root
    Relationship.new(:resource => self)
  end
  private :relationship_for_isolated_root

  # Returns a list of ancestor relationships, starting with the root relationship
  #   and ending with the parent relationship
  def ancestor_rels(*args)
    options = args.extract_options!
    rel = relationship(:raise_on_multiple => true) # TODO: Handle multiple nodes with a way to detect which node you want
    rels = rel.nil? ? [] : rel.ancestors
    Relationship.filter_by_resource_type(rels, options)
  end

  # Returns a list of ancestor records, starting with the root record and ending
  #   with the parent record
  def ancestors(*args)
    Relationship.resources(ancestor_rels(*args))
  end

  # Returns a list of ancestor class/id pairs, starting with the root class/id
  #   and ending with the parent class/id
  def ancestor_ids(*args)
    Relationship.resource_pairs(ancestor_rels(*args))
  end

  # Returns the number of ancestor records
  def ancestors_count(*args)
    ancestor_rels(*args).size
  end

  # Returns a list of the path relationships, starting with the root relationship
  #   and ending with the node's own relationship
  def path_rels(*args)
    options = args.extract_options!
    rel = relationship(:raise_on_multiple => true) # TODO: Handle multiple nodes with a way to detect which node you want
    rels = rel.nil? ? [relationship_for_isolated_root] : rel.path
    Relationship.filter_by_resource_type(rels, options)
  end

  # Returns a list of the path records, starting with the root record and ending
  #   with the node's own record
  def path(*args)
    Relationship.resources(path_rels(*args)) # TODO: Prevent preload of self which is in the list
  end

  # Returns a list of the path class/id pairs, starting with the root class/id
  #   and ending with the node's own class/id
  def path_ids(*args)
    Relationship.resource_pairs(path_rels(*args))
  end

  # Returns the number of records in the path
  def path_count(*args)
    path_rels(*args).size
  end

  # Returns a list of child relationships
  def child_rels(*args)
    options = args.extract_options!
    rels = relationships.flat_map(&:children).uniq
    Relationship.filter_by_resource_type(rels, options)
  end

  # Returns a list of child records
  def children(*args)
    Relationship.resources(child_rels(*args))
  end

  # Returns a list of child class/id pairs
  def child_ids(*args)
    Relationship.resource_pairs(child_rels(*args))
  end

  # Returns the number of child records
  def child_count(*args)
    child_rels(*args).size
  end

  # Returns true if the record has any children, false otherwise
  def has_children?
    relationships.any?(&:has_children?)
  end

  # Returns true if the record has no children, false otherwise
  def is_childless?
    relationships.all?(&:is_childless?)
  end

  # Returns a list of sibling relationships
  def sibling_rels(*args)
    options = args.extract_options!
    rels = relationships.flat_map(&:siblings).uniq
    Relationship.filter_by_resource_type(rels, options)
  end

  # Returns a list of sibling records
  def siblings(*args)
    Relationship.resources(sibling_rels(*args))
  end

  # Returns a list of sibling class/id pairs
  def sibling_ids(*args)
    Relationship.resource_pairs(sibling_rels(*args))
  end

  # Returns the number of sibling records
  def sibling_count(*args)
    sibling_rels(*args).size
  end

  # Returns true if the record's parent has more than one child
  def has_siblings?
    relationships.any?(&:has_siblings?)
  end

  # Returns true if the record is the only child of its parent
  def is_only_child?
    relationships.all?(&:is_only_child?)
  end

  # Returns a list of descendant relationships
  def descendant_rels(*args)
    options = args.extract_options!
    rels = relationships.flat_map(&:descendants).uniq
    Relationship.filter_by_resource_type(rels, options)
  end

  # Returns a list of descendant records
  def descendants(*args)
    Relationship.resources(descendant_rels(*args))
  end

  # Returns a list of descendant class/id pairs
  def descendant_ids(*args)
    Relationship.resource_pairs(descendant_rels(*args))
  end

  # Returns the number of descendant records
  def descendant_count(*args)
    descendant_rels(*args).size
  end

  # Returns the descendant relationships arranged in a tree
  def descendant_rels_arranged(*args)
    options = args.extract_options!
    rel = relationship(:raise_on_multiple => true)
    return {} if rel.nil?  # TODO: Should this return nil or init_relationship or Relationship.new in a Hash?
    Relationship.filter_by_resource_type(rel.descendants, options).arrange
  end

  # Returns the descendant class/id pairs arranged in a tree
  def descendant_ids_arranged(*args)
    Relationship.arranged_rels_to_resource_pairs(descendant_rels_arranged(*args))
  end

  # Returns the descendant records arranged in a tree
  def descendants_arranged(*args)
    Relationship.arranged_rels_to_resources(descendant_rels_arranged(*args))
  end

  # Returns a list of all relationships in the record's subtree
  def subtree_rels(*args)
    options = args.extract_options!
    # TODO: make this a single query (vs 3)
    # thus making filter_by_resource_type into a query
    rels = relationships.flat_map(&:subtree).uniq
    rels = [relationship_for_isolated_root] if rels.empty?
    Relationship.filter_by_resource_type(rels, options)
  end

  # Returns a list of all records in the record's subtree
  def subtree(*args)
    Relationship.resources(subtree_rels(*args)) # TODO: Prevent preload of self which is in the list
  end

  # Returns a list of all class/id pairs in the record's subtree
  def subtree_ids(*args)
    Relationship.resource_pairs(subtree_rels(*args))
  end

  # Returns the number of records in the record's subtree
  def subtree_count(*args)
    subtree_rels(*args).size
  end

  # Returns the subtree relationships arranged in a tree
  def subtree_rels_arranged(*args)
    options = args.extract_options!
    rel = relationship(:raise_on_multiple => true)
    return {relationship_for_isolated_root => {}} if rel.nil?
    Relationship.filter_by_resource_type(rel.subtree, options).arrange
  end

  # Returns the subtree class/id pairs arranged in a tree
  def subtree_ids_arranged(*args)
    Relationship.arranged_rels_to_resource_pairs(subtree_rels_arranged(*args))
  end

  # Returns the subtree records arranged in a tree
  def subtree_arranged(*args)
    Relationship.arranged_rels_to_resources(subtree_rels_arranged(*args))
  end

  def grandchild_rels(*args)
    options = args.extract_options!
    rels = relationships.inject(Relationship.none) do |stmt, r|
      stmt.or(r.grandchildren)
    end
    Relationship.filter_by_resource_type(rels, options)
  end

  def grandchildren(*args)
    Relationship.resources(grandchild_rels(*args))
  end

  def child_and_grandchild_rels(*args)
    options = args.extract_options!
    rels = relationships.inject(Relationship.none) do |stmt, r|
      stmt.or(r.child_and_grandchildren)
    end
    Relationship.filter_by_resource_type(rels, options)
  end

  # Return the depth of the node, root nodes are at depth 0
  def depth
    rel = relationship(:raise_on_multiple => true) # TODO: Handle multiple nodes with a way to detect which node you want
    rel.nil? ? 0 : rel.depth
  end

  #
  # Other methods
  #

  # Returns the relationship node for this record.  If there are multiple nodes,
  #   the first is returned, unless :raise_on_multiple is passed as true.
  def relationship(*args)
    options = args.extract_options!
    if options[:raise_on_multiple]
      rels = relationships.take(2)
      raise _("Multiple relationships found") if rels.length > 1
      rels.first
    else
      relationships.first
    end
  end

  # Adds a new relationship for this node
  def add_relationship(parent_rel = nil)
    clear_relationships_cache
    all_relationships.create!(
      :relationship => (parent_rel.nil? ? relationship_type : parent_rel.relationship),
      :parent       => parent_rel
    )
  end

  # Returns an existing relationship if found, otherwise creates a new one
  #   If parent_rel is passed, also connects the returned relationship to the
  #   parent, possibly delinking from an existing parent.
  def init_relationship(parent_rel = nil)
    rel = relationship
    if rel.nil?
      rel = add_relationship(parent_rel)
    elsif !parent_rel.nil?
      rel.update_attribute(:parent, parent_rel)
    end
    rel
  end

  # Returns a String form of the ancestor class/id pairs of the record
  #   Accepts the usual options, plus the options for Relationship.stringify_*,
  #   as well as :include_self which defaults to false.
  def relationship_ancestry(*args)
    stringify_options = args.extract_options!
    options = stringify_options.slice!(:field_delimiter, :record_delimiter, :exclude_class, :field_method, :include_self)

    include_self = stringify_options.delete(:include_self)
    field_method = stringify_options[:field_method] || :id

    meth = include_self ? :path : :ancestors
    meth = :"#{meth.to_s.singularize}_ids" if field_method == :id
    rels = send(meth, options)

    rels_meth = :"stringify_#{field_method == :id ? "resource_pairs" : "rels"}"
    Relationship.send(rels_meth, rels, stringify_options)
  end

  # Returns a list of all relationships in the tree from the root
  def fulltree_rels(*args)
    options = args.extract_options!
    root_id = relationship.try(:root_id)
    rels = root_id ? Relationship.subtree_of(root_id).uniq : [relationship_for_isolated_root]
    Relationship.filter_by_resource_type(rels, options)
  end

  # Returns a list of all records in the tree from the root
  def fulltree(*args)
    Relationship.resources(fulltree_rels(*args)) # TODO: Prevent preload of self which is in the list
  end

  # Returns a list of all class/id pairs in the tree from the root
  def fulltree_ids(*args)
    Relationship.resource_pairs(fulltree_rels(*args))
  end

  # Returns the number of records in the tree from the root
  def fulltree_count(*args)
    fulltree_rels(*args).size
  end

  # Returns the relationships in the tree from the root arranged in a tree
  def fulltree_rels_arranged(*args)
    options = args.extract_options!
    root_id = relationship.try(:root_id)
    return {relationship_for_isolated_root => {}} if root_id.nil?
    Relationship.filter_by_resource_type(Relationship.subtree_of(root_id), options).arrange
  end

  # Returns the class/id pairs in the tree from the root arranged in a tree
  def fulltree_ids_arranged(*args)
    Relationship.arranged_rels_to_resource_pairs(fulltree_rels_arranged(*args))
  end

  # Returns the records in the tree from the root arranged in a tree
  def fulltree_arranged(*args)
    Relationship.arranged_rels_to_resources(fulltree_rels_arranged(*args))
  end

  # Returns a list of all unique child types
  def child_types(*args)
    Relationship.resource_types(child_rels(*args))
  end

  def add_parent(parent)
    parent.with_relationship_type(relationship_type) { parent.add_child(self) }
  end

  def add_children(*child_objs)
    options = child_objs.extract_options!
    child_objs = child_objs.flatten

    # Determine which child relationships already exist
    unless options[:skip_check] || (child_ids = self.child_ids).empty?
      child_objs = child_objs.reject { |c| child_ids.include?([c.class.base_class.name, c.id]) }
    end

    return child_objs if child_objs.empty?

    # Add the child relationships that do not already exist
    Relationship.transaction do
      parent_rel = init_relationship
      child_objs.each do |c|
        c.with_relationship_type(relationship_type) do
          # init_relationship will de-link from an existing parent, so if the
          #   child is already connected to a parent, we just want add a new
          #   child relationship, creating a duplicate node in the tree.  However,
          #   if the child is a root, we want to use init_relationship to link
          #   to the new parent directly to avoid creating multiple roots in the
          #   tree.
          c.send(c.is_root? ? :init_relationship : :add_relationship, parent_rel)
        end
      end
    end

    child_objs.each(&:clear_relationships_cache)
    clear_relationships_cache

    child_objs
  end
  alias_method :add_child, :add_children

  def parent=(parent)
    if parent.nil?
      remove_all_parents
    else
      parent.with_relationship_type(relationship_type) do
        parent_rel = parent.init_relationship
        init_relationship(parent_rel)  # TODO: Deal with any multi-instances

        parent.clear_relationships_cache
      end
    end

    clear_relationships_cache
  end
  alias_method :replace_parent, :parent=

  #
  # Backward compatibility methods
  #

  alias_method :set_parent, :parent=
  alias_method :set_child,  :add_children

  def replace_children(*child_objs)
    child_objs = child_objs.flatten
    return remove_all_children if child_objs.empty?

    # Determine which child relationships should be destroyed, already exist, or should be added
    child_rels = self.child_rels

    child_rel_ids = child_rels.collect(&:resource_pair)
    child_obj_ids = child_objs.collect { |c| [c.class.base_class.name, c.id] }

    to_del = child_rel_ids - child_obj_ids
    to_del = child_rels.select { |r| to_del.include?(r.resource_pair) }

    to_add = child_obj_ids - child_rel_ids
    to_add, to_keep = child_objs.partition { |c| to_add.include?([c.class.base_class.name, c.id]) }

    Relationship.transaction do
      to_keep.each(&:clear_relationships_cache)
      remove_all_relationships(to_del)
      add_children(to_add, :skip_check => true)
    end
  end

  def remove_parent(parent)
    parent.with_relationship_type(relationship_type) { parent.remove_child(self) }
  end

  def remove_children(*child_objs)
    child_objs = child_objs.flatten.compact
    return child_objs if child_objs.empty?

    child_rels = self.child_rels

    # Determine which child relationships should be destroyed or already exist
    child_obj_ids = child_objs.collect { |c| [c.class.base_class.name, c.id] }
    to_del, to_keep = child_rels.partition { |r| child_obj_ids.include?(r.resource_pair) }

    child_objs.each(&:clear_relationships_cache)
    if to_keep.empty?
      remove_all_children
    else
      remove_all_relationships(to_del)
    end
  end
  alias_method :remove_child, :remove_children

  def remove_all_parents(*args)
    parents(*args).collect { |p| remove_parent(p) }
  end

  def remove_all_children(*args)
    # Determine if we are removing all or some children
    options = args.last.kind_of?(Hash) ? args.last : {}
    of_type = Array.wrap(options[:of_type])
    all_children_removed = of_type.empty? || (child_types - of_type).empty?

    if self.is_root? && all_children_removed
      remove_all_relationships
    else
      remove_all_relationships(child_rels(*args))
    end
  end

  def remove_all_relationships(*rels)
    rels = relationships if rels.empty?
    rels = rels.first if rels.length == 1 && rels.first.kind_of?(Array)

    unless rels.empty?
      Relationship.transaction do
        rels.each(&:destroy)
      end
      clear_relationships_cache
    end
    rels
  end

  def is_descendant_of?(obj)
    ancestor_ids.include?([obj.class.base_class.name, obj.id])
  end

  def is_ancestor_of?(obj)
    descendant_ids.include?([obj.class.base_class.name, obj.id])
  end

  def detect_ancestor(*args, &block)
    ancestors(*args).reverse.detect(&block)
  end

  #
  # Diagnostic methods
  #

  def puts_relationship_tree
    Relationship.puts_arranged_resources(subtree_arranged)
  end
end
