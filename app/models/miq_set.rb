class MiqSet < ApplicationRecord
  self.abstract_class = true
  self.inheritance_column = :set_type

  include UuidMixin

  acts_as_miq_taggable

  serialize :set_data

  validates :name, :presence => true, :uniqueness_when_changed => {:scope => [:set_type, :userid, :group_id], :if => proc { |c| c.class.in_my_region.exists?(:name => c.name) }}
  validates :description, :presence => true

  has_many :miq_set_memberships, :dependent => :delete_all
  has_many :members, :through => :miq_set_memberships
  alias miq_sets members
  alias children members

  belongs_to :owner, :polymorphic => true

  attr_writer :model_class

  def self.model_class
    @model_class ||= name.chomp("Set").constantize
  end

  def self.model_table_name
    @model_table_name ||= model_class.table_name
  end

  def self.inherited(subclass)
    # subclass.has_many subclass.model_table_name.to_sym, :through => :miq_set_memberships
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
    transaction do
      existing = miq_set_memberships.index_by { |ms| [ms.member_type, ms.member_id] }

      members.flat_map { |m| Array(m) }.each do |member|
        raise ArgumentError, "object of type #{member.class} may not be a member of a set of type #{self.class}" unless member.kind_of?(self.class.model_class)
        next if existing.include?([member.class.base_class.name, member.id])

        miq_set_memberships.create(:member => member)
      end
    end
  end
  alias add_children add_members
  alias add_member add_members
  alias add_child add_members
end
