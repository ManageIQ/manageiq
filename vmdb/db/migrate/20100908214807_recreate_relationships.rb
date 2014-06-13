class RecreateRelationships < ActiveRecord::Migration
  class RelationshipsOrig < ActiveRecord::Base
    self.table_name = :relationships

    belongs_to :parent, :polymorphic => true
    belongs_to :child,  :polymorphic => true
  end

  class Relationship < ActiveRecord::Base
    require 'ancestry'
    has_ancestry
  end

  def self.up
    tree, roots = say_with_time("Collect Relationships") do
      self.collect_relationships
    end

    remove_index :relationships, :relationship
    remove_index :relationships, [:parent_type, :parent_id]
    remove_index :relationships, [:child_type, :child_id]
    drop_table :relationships, :relationships_orig

    create_table :relationships do |t|
      t.string  :resource_type
      t.bigint  :resource_id
      t.string  :ancestry,    :limit => 2000
      t.string  :relationship
      t.timestamps
    end

    # Transfer existing relationships to the new table
    say_with_time("Migrate Relationships") do
      self.build_tree(tree, roots)
    end

    add_index :relationships, :ancestry
    add_index :relationships, [:resource_type, :resource_id, :relationship], :name => "index_relationships_on_resource_and_relationship"
  end

  def self.down
    remove_index :relationships, :ancestry

    # Handle case where an erroneous index name was created, but if not there silently ignore
    old_rails_level, Rails.logger.level = Rails.logger.level, Logger::ERROR # Temporarily disable warning logging since the index may not exist
    old_miq_level, $log.level = $log.level, Logger::FATAL                   # Temporarily disable error logging since the index may not exist
    remove_index(:relationships, :name => "index_relationships_on_resource_and_relationship") rescue nil
    remove_index(:relationships, [:resource_type, :resource_id, :relationship]) rescue nil
    Rails.logger.level = old_rails_level
    $log.level = old_miq_level

    drop_table :relationships

    create_table :relationships do |t|
      t.column  :parent_id,       :bigint
      t.column  :child_id,        :bigint
      t.column  :parent_type,     :string
      t.column  :child_type,      :string
      t.column  :operation,       :string
      t.column  :operation_type,  :string
      t.column  :user_id,         :string
      t.column  :created_on,      :datetime
      t.column  :updated_on,      :datetime
      t.column  :relationship,    :string
    end

    add_index :relationships, :relationship
    add_index :relationships, [:parent_type, :parent_id]
    add_index :relationships, [:child_type, :child_id]
  end

  private

  def self.collect_relationships
    relats = RelationshipsOrig.all(:include => [:parent, :child])
    tree = Hash.new { |h,k| h[k] = Hash.new }
    roots = Hash.new { |h,k| h[k] = Array.new }

    relats.each do |relat|
      next if relat.parent.nil? || relat.child.nil?

      t = tree[relat.relationship]

      parent = [relat.parent_type, relat.parent_id]
      p_data = [relat.created_on, relat.updated_on]
      t[parent] = {:item => parent, :data => p_data, :parents => [], :children => []} unless t.has_key?(parent)
      p_node = t[parent]

      child  = [relat.child_type, relat.child_id]
      c_data = [relat.created_on, relat.updated_on]
      c_node = t[child] = {:item => child, :data => c_data, :parents => [], :children => []} unless t.has_key?(child)
      c_node = t[child]

      p_node[:children] << c_node unless p_node[:children].any? { |p_child|  p_child[:item]  == child }
      c_node[:parents]  << p_node unless c_node[:parents].any?  { |c_parent| c_parent[:item] == parent }

      r = roots[relat.relationship]
      r << parent if p_node[:parents].empty? && !r.include?(parent)
      r.delete(child)
    end

    return tree, roots
  end

  # Build the tree top-down, which is more efficient than bottom-up (since in
  #   bottom-up, every node in a subtree is re-saved with a new ancestry as soon
  #   as the root node is assigned a parent)
  def self.build_tree(tree, roots)
    roots.each do |type, r|
      r.each do |root|
        root = tree[type][root]
        root_obj = create_obj(root, type, nil)
        build_tree_rec type, root, root_obj
      end
    end
  end

  def self.build_tree_rec(type, parent, parent_obj)
    parent[:children].each do |child|
      child_obj = create_obj(child, type, parent_obj)
      build_tree_rec(type, child, child_obj)
    end
  end

  def self.create_obj(node, rel, parent)
    r_type, r_id = *node[:item]
    created_on, updated_on = *node[:data]

#    depth = parent.nil? ? 0 : parent.depth + 1
#    puts "#{"  " * depth}#{r_type} #{r_id}"

    Relationship.create!(
      :resource_type => r_type,
      :resource_id   => r_id,
      :relationship  => rel,
      :parent        => parent,
      :created_at    => created_on,
      :updated_at    => updated_on
    )
  end
end
