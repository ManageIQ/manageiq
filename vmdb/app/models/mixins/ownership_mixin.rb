module OwnershipMixin
  extend ActiveSupport::Concern

  included do
    belongs_to :evm_owner, :class_name => "User"
    belongs_to :miq_group

    virtual_column :evm_owner_email,                      :type => :string,     :uses => :evm_owner
    virtual_column :evm_owner_name,                       :type => :string,     :uses => :evm_owner
    virtual_column :evm_owner_userid,                     :type => :string,     :uses => :evm_owner
    virtual_column :owned_by_current_user,                :type => :boolean,    :uses => :evm_owner_userid
    virtual_column :owning_ldap_group,                    :type => :string,     :uses => :miq_group
    virtual_column :owned_by_current_ldap_group,          :type => :boolean,    :uses => :owning_ldap_group
  end

  module ClassMethods
    def set_ownership(ids, options)
      errors = ActiveModel::Errors.new(self)
      objects = self.find_all_by_id(ids)
      missing = ids - objects.collect(&:id)
      errors.add(:missing_ids, "Unable to find #{self.name.pluralize} with the following ids #{missing.inspect}") unless missing.empty?

      objects.each do |obj|
        begin
          options.each_key do |k|
            col = case k
            when :owner then :evm_owner
            when :group then :miq_group
            else
              raise "Unknown option, '#{k}'"
            end
            obj.send("#{col}=", options[k])
          end
          obj.save
        rescue => err
          errors.add(:error_updating, "Error, '#{err.message}, updating #{self.name}: Name: [#{obj.name}], Id: [#{obj.id}]")
        end
      end

      return errors.empty? ? true : errors
    end

    def conditions_for_owned(user_or_group = nil)
      user_or_group ||= User.current_user

      case user_or_group
      when User
        ["evm_owner_id = ?", user_or_group.id]
      when MiqGroup
        ["miq_group_id = ?", user_or_group.id]
      end
    end

    def conditions_for_owned_or_group_owned(user_or_group = nil)
      user_or_group ||= User.current_user

      cond = conditions_for_owned(user_or_group)
      case user_or_group
      when MiqGroup
        cond
      when User
        group_cond = conditions_for_owned(user_or_group.current_group)
        cond[0] += " OR #{group_cond[0]}"
        cond << group_cond[1]
        cond
      end
    end

    def user_or_group_owned(user=nil)
      self.where(self.conditions_for_owned_or_group_owned(user)).to_a
    end

  end

  def evm_owner_email
    evm_owner.try(:email)
  end

  def evm_owner_name
    evm_owner.try(:name)
  end

  def evm_owner_userid
    evm_owner.try(:userid)
  end

  def owned_by_current_user
    User.current_userid && evm_owner_userid && User.current_userid.downcase == evm_owner_userid.downcase
  end

  def owning_ldap_group
    miq_group.try(:description)
  end

  def owned_by_current_ldap_group
    ldap_group = User.current_user.try(:ldap_group)
    ldap_group && owning_ldap_group && (owning_ldap_group.downcase == ldap_group.downcase)
  end
end
