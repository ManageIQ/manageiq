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
  ]

  included do
    extend Memoist

    cattr_accessor :default_relationship_type

    has_many :all_relationships, :class_name => "Relationship", :dependent => :destroy, :as => :resource

    memoize *MEMOIZED_METHODS
  end

  module ClassMethods
    def alias_with_relationship_type(m_new, m_old, rel_type = nil)
      define_method(m_new) do |*args|
        self.with_relationship_type(rel_type || self.default_relationship_type) { self.send(m_old, *args) }
      end
    end
  end

  def reload(*args)
    clear_relationships_cache
    super
  end

  def clear_relationships_cache(*args)
    options = args.extract_options!
    to_clear = options[:only] ? options[:only].to_miq_a : (RelationshipMixin::MEMOIZED_METHODS - options[:except].to_miq_a)
    flush_cache *to_clear

    association_cache.delete(:all_relationships)
  end

  #
  # relationship_type scoping methods
  #

  def relationship_types
    @relationship_types ||= []
  end

  def relationship_type
    self.relationship_types.blank? ? self.default_relationship_type : self.relationship_types.last
  end

  def relationship_type=(rel)
    unless self.relationship_type == rel
      self.relationship_types.push(rel)
      clear_relationships_cache(:except => :relationships_of)
    end
    return rel
  end

  def with_relationship_type(rel)
    raise "no block given" unless block_given?

    rel_changed = rel && (self.relationship_type != rel)
    self.relationship_type = rel unless rel.nil?

    begin
      return yield self
    ensure
      if rel_changed
        self.relationship_types.pop
        clear_relationships_cache(:except => :relationships_of)
      end
    end
  end

  def relationships_of(rel_type)
    if association_cache.include?(:all_relationships)
      self.all_relationships.select { |r| r.relationship == rel_type }
    else
      self.all_relationships.in_relationship(rel_type)
    end
  end

  def relationships
    self.relationships_of(self.relationship_type)
  end

  def relationship_ids
    self.relationships.collect { |r| r.id }
  end

  #
  # has_ancestry methods
  #

  # Returns all of the relationships of the parents of the record, [] for a root node
  def parent_rels(*args)
    options = args.extract_options!
    rels = self.relationships.collect { |r| r.parent }.compact
    return Relationship.filter_by_resource_type(rels, options)
  end

  # Returns all of the parents of the record, [] for a root node
  def parents(*args)
    args = RelationshipMixin.deprecate_of_type_parameter(*args)
    Relationship.resources(self.parent_rels(*args))
  end

  # Returns all of the class/id pairs of the parents of the record, [] for a root node
  def parent_ids(*args)
    Relationship.resource_pairs(self.parent_rels(*args))
  end

  # Returns the number of parents of the record
  def parent_count(*args)
    self.parent_rels(*args).size
  end

  # Returns the relationship of the parent of the record, nil for a root node
  def parent_rel(*args)
    rels = self.parent_rels(*args)
    raise "Multiple parents found." if rels.length > 1
    return rels.first
  end

  # Returns the parent of the record, nil for a root node
  def parent(*args)
    rels = self.parents(*args)
    raise "Multiple parents found." if rels.length > 1
    return rels.first
  end

  # Returns the class/id pair of the parent of the record, nil for a root node
  def parent_id(*args)
    rels = self.parent_ids(*args)
    raise "Multiple parents found." if rels.length > 1
    return rels.first
  end

  # Returns the relationship of the root of the tree the record is in
  def root_rel(*args)
    rel = self.relationship
    return rel.nil? ? nil : rel.root # TODO: Should this return nil or init_relationship or Relationship.new?
  end

  # Returns the root of the tree the record is in, self for a root node
  def root(*args)
    return self if self.is_root?(*args)
    Relationship.resource(self.root_rel(*args))
  end

  # Returns the id of the root of the tree the record is in
  def root_id(*args)
    return [self.class.base_class.name, self.id] if self.is_root?(*args)
    Relationship.resource_pair(self.root_rel(*args))
  end

  # Returns true if the record is a root node, false otherwise
  def is_root?(*args)
    rel = self.relationship # TODO: Handle a node that is a root and a node at the same time
    return rel.nil? ? true : rel.is_root?
  end

  # Returns true if the record is a root node and does not have a corresponding
  #   relationship record, meaning it is an isolated root node; false otherwise
  def is_isolated_root?(*args)
    self.relationship.nil?
  end

  # Returns a list of ancestor relationships, starting with the root relationship
  #   and ending with the parent relationship
  def ancestor_rels(*args)
    options = args.extract_options!
    rel = self.relationship(:raise_on_multiple => true) #TODO: Handle multiple nodes with a way to detect which node you want
    rels = rel.nil? ? [] : rel.ancestors
    return Relationship.filter_by_resource_type(rels, options)
  end

  # Returns a list of ancestor records, starting with the root record and ending
  #   with the parent record
  def ancestors(*args)
    args = RelationshipMixin.deprecate_of_type_parameter(*args)
    Relationship.resources(self.ancestor_rels(*args))
  end

  # Returns a list of ancestor class/id pairs, starting with the root class/id
  #   and ending with the parent class/id
  def ancestor_ids(*args)
    Relationship.resource_pairs(self.ancestor_rels(*args))
  end

  # Returns the number of ancestor records
  def ancestors_count(*args)
    self.ancestor_rels(*args).size
  end

  # Returns a list of the path relationships, starting with the root relationship
  #   and ending with the node's own relationship
  def path_rels(*args)
    options = args.extract_options!
    rel = self.relationship(:raise_on_multiple => true) #TODO: Handle multiple nodes with a way to detect which node you want
    rels = rel.nil? ? [] : rel.path
    return Relationship.filter_by_resource_type(rels, options)
  end

  # Returns a list of the path records, starting with the root record and ending
  #   with the node's own record
  def path(*args)
    return [self] if self.is_isolated_root? # TODO: Should this return nil or init_relationship or Relationship.new in an Array?
    Relationship.resources(self.path_rels(*args)) #TODO: Prevent preload of self which is in the list
  end

  # Returns a list of the path class/id pairs, starting with the root class/id
  #   and ending with the node's own class/id
  def path_ids(*args)
    return [[self.class.base_class.name, self.id]] if self.is_isolated_root? # TODO: Should this return nil or init_relationship or Relationship.new in a Array?
    Relationship.resource_pairs(self.path_rels(*args))
  end

  # Returns the number of records in the path
  def path_count(*args)
    return 1 if self.is_isolated_root? # TODO: Should this return nil or init_relationship or Relationship.new?
    self.path_rels(*args).size
  end

  # Returns a list of child relationships
  def child_rels(*args)
    options = args.extract_options!
    rels = self.relationships.flat_map { |r| r.children }.uniq
    return Relationship.filter_by_resource_type(rels, options)
  end

  # Returns a list of child records
  def children(*args)
    args = RelationshipMixin.deprecate_of_type_parameter(*args)
    Relationship.resources(self.child_rels(*args))
  end

  # Returns a list of child class/id pairs
  def child_ids(*args)
    Relationship.resource_pairs(self.child_rels(*args))
  end

  # Returns the number of child records
  def child_count(*args)
    self.child_rels(*args).size
  end

  # Returns true if the record has any children, false otherwise
  def has_children?(*args)
    self.relationships.any? { |r| r.has_children? }
  end

  # Returns true if the record has no children, false otherwise
  def is_childless?(*args)
    self.relationships.all? { |r| r.is_childless? }
  end

  # Returns a list of sibling relationships
  def sibling_rels(*args)
    options = args.extract_options!
    rels = self.relationships.flat_map { |r| r.siblings }.uniq
    return Relationship.filter_by_resource_type(rels, options)
  end

  # Returns a list of sibling records
  def siblings(*args)
    Relationship.resources(self.sibling_rels(*args))
  end

  # Returns a list of sibling class/id pairs
  def sibling_ids(*args)
    Relationship.resource_pairs(self.sibling_rels(*args))
  end

  # Returns the number of sibling records
  def sibling_count(*args)
    self.sibling_rels(*args).size
  end

  # Returns true if the record's parent has more than one child
  def has_siblings?(*args)
    self.relationships.any? { |r| r.has_siblings? }
  end

  # Returns true if the record is the only child of its parent
  def is_only_child?(*args)
    self.relationships.all? { |r| r.is_only_child? }
  end

  # Returns a list of descendant relationships
  def descendant_rels(*args)
    options = args.extract_options!
    rels = self.relationships.flat_map { |r| r.descendants }.uniq
    return Relationship.filter_by_resource_type(rels, options)
  end

  # Returns a list of descendant records
  def descendants(*args)
    args = RelationshipMixin.deprecate_of_type_parameter(*args)
    Relationship.resources(self.descendant_rels(*args))
  end

  # Returns a list of descendant class/id pairs
  def descendant_ids(*args)
    Relationship.resource_pairs(self.descendant_rels(*args))
  end

  # Returns the number of descendant records
  def descendant_count(*args)
    self.descendant_rels(*args).size
  end

  # Returns the descendant relationships arranged in a tree
  def descendant_rels_arranged(*args)
    options = args.extract_options!
    rel = self.relationship(:raise_on_multiple => true)
    return {} if rel.nil?  # TODO: Should this return nil or init_relationship or Relationship.new in a Hash?
    return Relationship.filter_arranged_rels_by_resource_type(rel.descendants.arrange, options)
  end

  # Returns the descendant class/id pairs arranged in a tree
  def descendant_ids_arranged(*args)
    Relationship.arranged_rels_to_resource_pairs(self.descendant_rels_arranged(*args))
  end

  # Returns the descendant records arranged in a tree
  def descendants_arranged(*args)
    Relationship.arranged_rels_to_resources(self.descendant_rels_arranged(*args))
  end

  # Returns a list of all relationships in the record's subtree
  def subtree_rels(*args)
    options = args.extract_options!
    rels = self.relationships.flat_map { |r| r.subtree }.uniq
    return Relationship.filter_by_resource_type(rels, options)
  end

  # Returns a list of all records in the record's subtree
  def subtree(*args)
    return [self] if self.is_isolated_root? # TODO: Should this return nil or init_relationship or Relationship.new in an Array?
    Relationship.resources(self.subtree_rels(*args)) #TODO: Prevent preload of self which is in the list
  end

  # Returns a list of all class/id pairs in the record's subtree
  def subtree_ids(*args)
    return [[self.class.base_class.name, self.id]] if self.is_isolated_root? # TODO: Should this return nil or init_relationship or Relationship.new in an Array?
    Relationship.resource_pairs(self.subtree_rels(*args))
  end

  # Returns the number of records in the record's subtree
  def subtree_count(*args)
    return 1 if self.is_isolated_root? # TODO: Should this return nil or init_relationship or Relationship.new?
    self.subtree_rels(*args).size
  end

  # Returns the subtree relationships arranged in a tree
  def subtree_rels_arranged(*args)
    options = args.extract_options!
    rel = self.relationship(:raise_on_multiple => true)
    return {} if rel.nil?  # TODO: Should this return nil or init_relationship or Relationship.new in a Hash?
    return Relationship.filter_arranged_rels_by_resource_type(rel.subtree.arrange, options)
  end

  # Returns the subtree class/id pairs arranged in a tree
  def subtree_ids_arranged(*args)
    return {[self.class.base_class.name, self.id] => {}} if self.is_isolated_root? # TODO: Should this return nil or init_relationship or Relationship.new in a Hash?
    Relationship.arranged_rels_to_resource_pairs(self.subtree_rels_arranged(*args))
  end

  # Returns the subtree records arranged in a tree
  def subtree_arranged(*args)
    return {self => {}} if self.is_isolated_root? # TODO: Should this return nil or init_relationship or Relationship.new in a Hash?
    Relationship.arranged_rels_to_resources(self.subtree_rels_arranged(*args))
  end

  # Return the depth of the node, root nodes are at depth 0
  def depth(*args)
    rel = self.relationship(:raise_on_multiple => true) #TODO: Handle multiple nodes with a way to detect which node you want
    return rel.nil? ? 0 : rel.depth
  end

  #
  # Other methods
  #

  # Returns the relationship node for this record.  If there are multiple nodes,
  #   the first is returned, unless :raise_on_multiple is passed as true.
  def relationship(*args)
    options = args.extract_options!
    raise "Multiple relationships found" if options[:raise_on_multiple] and self.has_multiple_relationships?
    return self.relationships.first
  end

  def has_multiple_relationships?
    return self.relationships.size > 1
  end

  # Adds a new relationship for this node
  def add_relationship(parent_rel = nil)
    self.clear_relationships_cache
    self.all_relationships.create!(
      :relationship => (parent_rel.nil? ? self.relationship_type : parent_rel.relationship),
      :parent       => parent_rel
    )
  end

  # Returns an existing relationship if found, otherwise creates a new one
  #   If parent_rel is passed, also connects the returned relationship to the
  #   parent, possibly delinking from an existing parent.
  def init_relationship(parent_rel = nil)
    rel = self.relationship
    if rel.nil?
      rel = self.add_relationship(parent_rel)
    elsif !parent_rel.nil?
      rel.update_attribute(:parent, parent_rel)
    end
    return rel
  end

  # Returns a String form of the ancestor class/id pairs of the record
  #   Accepts the usual options, plus the options for Relationship.stringify_*,
  #   as well as :include_self which defaults to false.
  def ancestry(*args)
    stringify_options = args.extract_options!
    options = stringify_options.slice!(:field_delimiter, :record_delimiter, :exclude_class, :field_method, :include_self)

    include_self = stringify_options.delete(:include_self)
    field_method = stringify_options[:field_method] || :id

    meth = include_self ? :path : :ancestors
    meth = :"#{meth.to_s.singularize}_ids" if field_method == :id
    rels = self.send(meth, options)

    rels_meth = :"stringify_#{field_method == :id ? "resource_pairs" : "rels"}"
    return Relationship.send(rels_meth, rels, stringify_options)
  end

  # Returns a list of all relationships in the tree from the root
  def fulltree_rels(*args)
    options = args.extract_options!
    return [] if self.is_isolated_root? # TODO: Should this return nil or init_relationship or Relationship.new in an Array?
    root_id = self.relationship.root_id
    rels = Relationship.subtree_of(root_id).uniq
    return Relationship.filter_by_resource_type(rels, options)
  end

  # Returns a list of all records in the tree from the root
  def fulltree(*args)
    return [self] if self.is_isolated_root? # TODO: Should this return nil or init_relationship or Relationship.new in an Array?
    Relationship.resources(self.fulltree_rels(*args)) #TODO: Prevent preload of self which is in the list
  end

  # Returns a list of all class/id pairs in the tree from the root
  def fulltree_ids(*args)
    return [[self.class.base_class.name, self.id]] if self.is_isolated_root? # TODO: Should this return nil or init_relationship or Relationship.new in an Array?
    Relationship.resource_pairs(self.fulltree_rels(*args))
  end

  # Returns the number of records in the tree from the root
  def fulltree_count(*args)
    return 1 if self.is_isolated_root?
    self.fulltree_rels(*args).size
  end

  # Returns the relationships in the tree from the root arranged in a tree
  def fulltree_rels_arranged(*args)
    options = args.extract_options!
    return {} if self.is_isolated_root? # TODO: Should this return nil or init_relationship or Relationship.new in a Hash?
    root_id = self.relationship.root_id
    rels = Relationship.subtree_of(root_id).arrange
    return Relationship.filter_arranged_rels_by_resource_type(rels, options)
  end

  # Returns the class/id pairs in the tree from the root arranged in a tree
  def fulltree_ids_arranged(*args)
    return {[self.class.base_class.name, self.id] => {}} if self.is_isolated_root? # TODO: Should this return nil or init_relationship or Relationship.new in a Hash?
    Relationship.arranged_rels_to_resource_pairs(self.fulltree_rels_arranged(*args))
  end

  # Returns the records in the tree from the root arranged in a tree
  def fulltree_arranged(*args)
    return {self => {}} if self.is_isolated_root? # TODO: Should this return nil or init_relationship or Relationship.new in a Hash?
    Relationship.arranged_rels_to_resources(self.fulltree_rels_arranged(*args))
  end

  # Returns a list of all unique child types
  def child_types(*args)
    Relationship.resource_types(self.child_rels(*args))
  end

  def parent=(parent)
    parent.with_relationship_type(self.relationship_type) { parent.add_child(self) }
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
      parent_rel = self.init_relationship
      child_objs.each do |c|
        c.with_relationship_type(self.relationship_type) do
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

    child_objs.each { |c| c.clear_relationships_cache }
    self.clear_relationships_cache

    return child_objs
  end
  alias add_child add_children

  #
  # Backward compatibility methods
  #

  alias set_parent parent=
  alias set_child  add_children

  def replace_parent(parent)
    if parent.nil?
      self.remove_all_parents
    else
      parent.with_relationship_type(self.relationship_type) do
        parent_rel = parent.init_relationship
        self.init_relationship(parent_rel)  # TODO: Deal with any multi-instances
      end
    end

    self.clear_relationships_cache
  end

  def replace_children(*child_objs)
    child_objs = child_objs.flatten
    return self.remove_all_children if child_objs.empty?

    # Determine which child relationships should be destroyed, already exist, or should be added
    child_rels = self.child_rels

    child_rel_ids = child_rels.collect { |r| r.resource_pair }
    child_obj_ids = child_objs.collect { |c| [c.class.base_class.name, c.id] }

    to_del = child_rel_ids - child_obj_ids
    to_del = child_rels.select { |r| to_del.include?(r.resource_pair) }

    to_add = child_obj_ids - child_rel_ids
    to_add, to_keep = child_objs.partition { |c| to_add.include?([c.class.base_class.name, c.id]) }

    Relationship.transaction do
      to_keep.each { |c| c.clear_relationships_cache }
      self.remove_all_relationships(to_del)
      self.add_children(to_add, :skip_check => true)
    end
  end

  def remove_parent(parent)
    parent.with_relationship_type(self.relationship_type) { parent.remove_child(self) }
  end

  def remove_children(*child_objs)
    child_objs = child_objs.flatten
    return child_objs if child_objs.empty?

    child_rels = self.child_rels

    # Determine which child relationships should be destroyed or already exist
    child_obj_ids = child_objs.collect { |c| [c.class.base_class.name, c.id] }
    to_del, to_keep = child_rels.partition { |r| child_obj_ids.include?(r.resource_pair) }

    child_objs.each { |c| c.clear_relationships_cache }
    if to_keep.empty?
      self.remove_all_children
    else
      self.remove_all_relationships(to_del)
    end
  end
  alias remove_child remove_children

  def remove_all_parents(*args)
    args = RelationshipMixin.deprecate_of_type_and_rel_type_parameter(*args)
    self.parents(*args).collect { |p| self.remove_parent(p) }
  end

  def remove_all_children(*args)
    args = RelationshipMixin.deprecate_of_type_and_rel_type_parameter(*args)

    # Determine if we are removing all or some children
    options = args.last.kind_of?(Hash) ? args.last : {}
    of_type = options[:of_type].to_miq_a
    all_children_removed = of_type.empty? || (self.child_types - of_type).empty?

    if self.is_root? && all_children_removed
      self.remove_all_relationships
    else
      self.remove_all_relationships(self.child_rels(*args))
    end
  end

  def remove_all_relationships(*rels)
    rels = self.relationships if rels.empty?
    rels = rels.first if rels.length == 1 && rels.first.kind_of?(Array)

    unless rels.empty?
      Relationship.transaction do
        rels.each { |r| r.destroy }
      end
      self.clear_relationships_cache
    end
    return rels
  end

  def is_descendant_of?(obj)
    self.ancestor_ids.include?([obj.class.base_class.name, obj.id])
  end

  def is_ancestor_of?(obj)
    self.descendant_ids.include?([obj.class.base_class.name, obj.id])
  end

  def detect_ancestor(*args, &block)
    args = RelationshipMixin.deprecate_start_parameter(*args)
    self.ancestors(*args).reverse.detect(&block)
  end

  # TODO: Replace these or get rid of them
  alias clear_children_cache clear_relationships_cache
  alias clear_parents_cache  clear_relationships_cache

  #
  # Diagnostic methods
  #

  def puts_relationship_tree
    Relationship.puts_arranged_resources(subtree_arranged)
  end

  #
  # Deprecation methods
  #

  def self.deprecate_of_type_parameter(*args)
    return args if args.empty? || args.first.kind_of?(Hash)

    unless Rails.env.production?
      msg = "[DEPRECATION] of_type parameter without hash symbol is deprecated.  Please use :of_type => 'Type' style instead.  At #{caller[1]}"
      $log.warn msg
      warn msg
    end

    options = args.extract_options!
    return [options.merge(:of_type => args.first)]
  end

  def self.deprecate_of_type_and_rel_type_parameter(*args)
    return args if args.empty? || args.first.kind_of?(Hash)

    unless Rails.env.production?
      msg = "[DEPRECATION] of_type parameter without hash symbol is deprecated.  Please use :of_type => 'Type' style instead.  At #{caller[1]}"
      $log.warn msg
      warn msg
    end

    options = args.extract_options!

    if args.length > 1
      unless Rails.env.production?
        msg = "[DEPRECATION] relationship_type parameter is deprecated.  Please use with_relationship_type method before calling instead.  At #{caller[1]}"
        $log.warn msg
        warn msg
      end
    end

    return [options.merge(:of_type => args.first)]
  end

  def self.deprecate_start_parameter(*args)
    return args if args.empty? || args.first.kind_of?(Hash)

    unless Rails.env.production?
      msg = "[DEPRECATION] start parameter is deprecated.  At #{caller[1]}"
      $log.warn msg
      warn msg
    end

    return [args.extract_options!]
  end
end
