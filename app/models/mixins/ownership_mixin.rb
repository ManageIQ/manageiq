module OwnershipMixin
  extend ActiveSupport::Concern

  included do
    belongs_to :evm_owner, :class_name => "User"
    belongs_to :miq_group

    virtual_column :evm_owner_email,                      :type => :string,     :uses => :evm_owner
    virtual_column :evm_owner_name,                       :type => :string,     :uses => :evm_owner
    virtual_column :evm_owner_userid,                     :type => :string,     :uses => :evm_owner
    virtual_column :owning_ldap_group,                    :type => :string,     :uses => :miq_group

    # Determine whether to return objects owned by the current user's miq_group
    # or not. Requires `with_miq_group` scope to function
    #
    # Resulting SQL: "(LOWER("miq_groups"."description") = 'some_miq_group')"
    #
    # Will result in the following when used with MiqExpression:
    #
    #   WHERE ((LOWER("miq_groups"."description") = 'some_miq_group') = 'true')
    virtual_attribute :owned_by_current_ldap_group, :boolean, :arel => (lambda do |t|
      ldap_group = User.current_user.try(:ldap_group).to_s.downcase

      t.grouping(MiqGroup.arel_table[:description].lower.eq(ldap_group))
    end)

    # Determine whether to return objects owned by the current user or not
    # Requires `with_miq_group` scope to function
    #
    # Resulting SQL: "(LOWER("users"."userid") = 'some_userid')"
    #
    # Will result in the following when used with MiqExpression:
    #
    #   WHERE ((LOWER("users"."userid") = 'some_userid') = 'true')
    virtual_attribute :owned_by_current_user, :boolean, :arel => (lambda do |t|
      t.grouping(User.arel_table[:userid].lower.eq(User.current_userid.downcase))
    end)
  end

  module ClassMethods
    def with_miq_group
      select(arel_table[Arel.star]).joins(:miq_group)
    end

    def with_evm_owner
      select(arel_table[Arel.star]).joins(:evm_owner)
    end

    def set_ownership(ids, options)
      errors = ActiveModel::Errors.new(self)
      objects = where(:id => ids)
      missing = ids - objects.collect(&:id)
      errors.add(:missing_ids, "Unable to find #{name.pluralize} with the following ids #{missing.inspect}") unless missing.empty?

      objects.each do |obj|
        begin
          options.each_key do |k|
            col = case k
                  when :owner then :evm_owner
                  when :group then :miq_group
                  else
                    raise _("Unknown option, '%{name}'") % {:name => k}
                  end
            obj.send("#{col}=", options[k])
          end
          obj.save
        rescue => err
          errors.add(:error_updating, "Error, '#{err.message}, updating #{name}: Name: [#{obj.name}], Id: [#{obj.id}]")
        end
      end

      errors.empty? ? true : errors
    end

    def user_or_group_owned(user, miq_group)
      if user && miq_group
        where("evm_owner_id" => user.id).or(where("miq_group_id" => miq_group.id))
      elsif user
        where("evm_owner_id" => user.id)
      elsif miq_group
        where("miq_group_id" => miq_group.id)
      else
        none
      end
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
