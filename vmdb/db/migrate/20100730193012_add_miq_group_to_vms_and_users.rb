class AddMiqGroupToVmsAndUsers < ActiveRecord::Migration
  class Vm < ActiveRecord::Base
    serialize :reserved
    belongs_to :miq_group, :class_name => "AddMiqGroupToVmsAndUsers::MiqGroup"
    self.inheritance_column = :_type_disabled  # disable STI
  end

  class User < ActiveRecord::Base
    serialize :reserved
    belongs_to :miq_group, :class_name => "AddMiqGroupToVmsAndUsers::MiqGroup"
  end

  class MiqGroup < ActiveRecord::Base; end

  def self.up
    add_column      :users,   :miq_group_id,   :bigint
    add_column      :vms,     :miq_group_id,   :bigint

    # cache the miq_groups to avoid lookups via query in loop below
    groups = {}
    groups = MiqGroup.all.each_with_object({}) {|group, hash| hash[group.description] = group.id}

    [Vm, :owning_ldap_group, User, :ldap_group].each_slice(2) do |klass, key|
      say_with_time("Migrate data from reserved column to #{klass.name.split("::").last} #{key}") do
        t = klass.arel_table
        klass.where(t[:reserved].not_eq nil).each do |obj|
          res = obj.reserved
          next unless res.kind_of?(Hash) && res.has_key?(key)
          group = res.delete(key)
          obj.miq_group_id = groups[group]
          obj.reserved = res.empty? ? nil : res
          obj.save
        end
      end
    end
  end

  def self.down
    # Convert data in column to the reserved column

    # cache the miq_groups to avoid lookups via query in loop below
    groups = {}
    groups = MiqGroup.all.each_with_object({}) {|group, hash| hash[group.id] = group.description}

    [Vm, :owning_ldap_group, User, :ldap_group].each_slice(2) do |klass, key|
      say_with_time("Migrate data to reserved column from #{klass.name.split("::").last} #{key}") do
        t = klass.arel_table
        klass.where(t[:miq_group_id].not_eq nil).each do |obj|
          obj.reserved ||= {}
          group_description = groups[obj.miq_group_id]
          next if group_description.nil?
          obj.reserved[key] = group_description
          obj.save
        end
      end
    end

    remove_column   :users,   :miq_group_id
    remove_column   :vms,     :miq_group_id
  end
end
