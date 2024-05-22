module ActsAsMiqSetMember
  extend ActiveSupport::Concern

  included do
    MiqSetMembership.send(:belongs_to, miq_set_class.name.underscore.to_sym, :foreign_key => :miq_set_id)

    has_many :miq_set_memberships,
             :as        => :member,
             :dependent => :delete_all

    has_many :miq_sets,
             :class_name => miq_set_class.to_s, # rubocop:disable Rails/ReflectionClassName
             :source     => miq_set_class.name.underscore.to_sym,
             :through    => :miq_set_memberships

    has_many :memberof,
             :class_name => miq_set_class.to_s, # rubocop:disable Rails/ReflectionClassName
             :source     => miq_set_class.name.underscore.to_sym,
             :through    => :miq_set_memberships

    has_many miq_set_class.name.underscore.pluralize.to_sym,
             :class_name => miq_set_class.to_s, # rubocop:disable Rails/ReflectionClassName
             :source     => miq_set_class.name.underscore.to_sym,
             :through    => :miq_set_memberships
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

  def make_not_memberof(set)
    set.remove_member(self)
  end
end # module ActsAsMiqSetMember

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

module ActsAsMiqSet
  extend ActiveSupport::Concern
  included do
    include UuidMixin

    self.table_name         = "miq_sets"
    self.inheritance_column = :set_type

    serialize :set_data

    validates :name,
              :presence                => true,
              :uniqueness_when_changed => {
                :scope => [:set_type, :userid, :group_id],
                :if    => proc { |c| c.class.in_my_region.exists?(:name => c.name) }
              }
    validates :description,
              :presence => true

    belongs_to :owner,
               :polymorphic => true
    has_many   :miq_set_memberships,
               :foreign_key => :miq_set_id,
               :dependent   => :delete_all

    acts_as_miq_taggable

    [:members, :miq_sets, :children, model_table_name.to_sym].each do |hm_relation|
      has_many hm_relation,
               :through     => :miq_set_memberships,
               :source      => :member,
               :source_type => model_class.name.to_s
    end
  end

  module ClassMethods
    # HACK: We need to do this to fake AR into doing STI so that polymorphic relationships to
    #       this class save the *_type column with the full sub-class's name as opposed to the
    #       base model class. This is needed so that tagging works properly. Once tagging is reworked
    #       to handle the base model class name this can be removed and real STI can be used.
    def descends_from_active_record?; false; end

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

  def members=(*members)
    transaction do
      remove_all_members
      add_members(*members)
    end
  end
  alias replace_children members=

  def remove_member(member)
    miq_set_memberships.where(:member => member).delete_all
  end
  alias remove_child remove_member

  def remove_all_members
    miq_set_memberships.delete_all
  end
  alias remove_all_children remove_all_members

  def add_members(*members)
    added = []

    transaction do
      existing = miq_set_memberships.index_by { |ms| [ms.member_type, ms.member_id] }

      members.flatten.each do |member|
        raise ArgumentError, "object of type #{member.class} may not be a member of a set of type #{self.class}" unless member.kind_of?(self.class.model_class)
        next if existing.include?([member.class.base_class.name, member.id])

        miq_set_memberships.create!(:member => member)
        added << member
      end
    end

    added
  end
  alias add_children add_members
  alias add_member add_members
  alias add_child add_members
end # module ActsAsMiqSet
