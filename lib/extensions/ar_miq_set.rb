module ActiveRecord
  class Base
    def self.acts_as_miq_set_member
      include ActsAsMiqSetMember
    end

    def self.acts_as_miq_set(model_class = nil)
      include ActsAsMiqSet

      self.model_class = model_class unless model_class.nil?
    end
  end
end

module ActsAsMiqSetMember
  extend ActiveSupport::Concern
  included do
    include RelationshipMixin
    self.default_relationship_type = "membership"

    alias_with_relationship_type :memberof,          :parents
    alias_with_relationship_type :make_not_memberof, :remove_parent
  end

  module ClassMethods
    def miq_set_class
      @miq_set_class ||= "#{name}Set".constantize
    end

    def sets
      miq_set_class.all
    end
  end # module SingletonMethods

  def make_memberof(set)
    set.add_member(self)
  end
end # module ActsAsMiqSetMember

module ActsAsMiqSet
  extend ActiveSupport::Concern
  included do
    include RelationshipMixin
    self.default_relationship_type ||= "membership"

    include UuidMixin

    self.table_name         = "miq_sets"
    self.inheritance_column = :set_type

    serialize :set_data

    validates_presence_of     :name
    validates_uniqueness_of   :name,
                              :scope => [:set_type, :userid, :group_id],
                              :if    => proc { |c| c.class.in_my_region.exists?(:name => c.name) }
    validates_presence_of     :description

    belongs_to  :owner, :polymorphic => true

    acts_as_miq_taggable

    alias_with_relationship_type :members,            :children
    alias_with_relationship_type :miq_sets,           :children
    alias_with_relationship_type :remove_member,      :remove_child
    alias_with_relationship_type :remove_all_members, :remove_all_children

    alias_method model_table_name.to_sym, :children
  end

  module ClassMethods
    # HACK: We need to do this to fake AR into doing STI so that polymorphic relationships to
    #       this class save the *_type column with the full sub-class's name as opposed to the
    #       base model class. This is needed so that tagging works properly. Once tagging is reworked
    #       to handle the base model class name this can be removed and real STI can be used.
    def descends_from_active_record?; false; end
    #

    def model_class
      @model_class ||= name[0..-4].constantize
    end

    def model_class=(val)
      @model_class = val
    end

    def model_table_name
      @model_table_name ||= model_class.table_name
    end
  end

  def add_member(member)
    raise "object of type #{member.class} may not be a member of a set of type #{self.class}" unless member.kind_of?(self.class.model_class)
    with_relationship_type("membership") { add_child(member) }
  end
end # module ActsAsMiqSet
