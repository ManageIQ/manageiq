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
      missing = ids - objects.collect {|obj| obj.id}
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
      self.all(:conditions => self.conditions_for_owned_or_group_owned(user))
    end

  end

  def evm_owner_email
    self.evm_owner.nil? ? nil : self.evm_owner.email
  end

  def evm_owner_name
    self.evm_owner.nil? ? nil : self.evm_owner.name
  end

  def evm_owner_userid
    self.evm_owner.nil? ? nil : self.evm_owner.userid
  end

  def owned_by_current_user
    return false if User.current_userid.nil? || self.evm_owner_userid.nil?
    User.current_userid.downcase == self.evm_owner_userid.downcase
  end

  def owning_ldap_group
    self.miq_group ? self.miq_group.description : nil
  end

  def owned_by_current_ldap_group
    ldap_group = User.current_user_ldap_group
    return false if ldap_group.nil? || self.owning_ldap_group.nil?

    self.owning_ldap_group.downcase == User.current_user_ldap_group.downcase
  end


end
