module OwnershipMixin
  extend ActiveSupport::Concern

  included do
    belongs_to :evm_owner, :class_name => "User"
    belongs_to :miq_group

    virtual_column :evm_owner_email,                      :type => :string,     :uses => :evm_owner
    virtual_column :evm_owner_name,                       :type => :string,     :uses => :evm_owner

    # This is a backported version of the virtual_delegate form of this
    # (changed in https://github.com/ManageIQ/manageiq/pull/11243 ) which is to
    # help support the bug fix from
    # https://github.com/ManageIQ/manageiq/pull/11992
    virtual_column :evm_owner_userid, :type => :string, :uses => :evm_owner, :arel => (lambda do |t|
      user_table = User.arel_table
      t.grouping(
        user_table.project(user_table[:userid])
                  .where(user_table[:id].eq(t[:evm_owner_id]))
      )
    end)

    # Determine whether the selected object is owned by the current user
    # Resulting SQL:
    #
    #   ((SELECT (LOWER("users"."userid") = 'some_userid')
    #     FROM "users"
    #     WHERE "users"."id" = "THIS_MODELS_TABLE"."evm_owner_id"))
    virtual_attribute :owned_by_current_user, :boolean, :arel => (lambda do |t|
      user_table = User.arel_table
      group_sel  = t.grouping(user_table[:userid].lower.eq(User.current_userid.to_s.try(:downcase)))
      where_cond = user_table[:id].eq(arel_attribute(:evm_owner_id))

      t.grouping(user_table.project(group_sel).where(where_cond))
    end)

    virtual_column :owning_ldap_group,                    :type => :string,     :uses => :miq_group

    # Determine whether to return objects owned by the current user's miq_group
    # or not.
    #
    # Resulting SQL:
    #
    #   ((SELECT (LOWER("miq_groups"."description") = 'some_miq_group')
    #     FROM "miq_groups"
    #     WHERE "miq_groups"."id" = "THIS_MODELS_TABLE"."miq_group_id"))
    #
    # Will result in the following when used with MiqExpression:
    #
    #   WHERE (((SELECT (LOWER("miq_groups"."description") = 'some_miq_group')
    #            FROM "miq_groups"
    #            WHERE "miq_groups"."id" = "THIS_MODELS_TABLE"."miq_group_id")) = 'true')
    virtual_attribute :owned_by_current_ldap_group, :boolean, :arel => (lambda do |t|
      group_tbl  = MiqGroup.arel_table
      ldap_group = User.current_user.try(:ldap_group).to_s.downcase
      group_sel  = t.grouping(group_tbl[:description].lower.eq(ldap_group))
      where_cond = group_tbl[:id].eq(arel_attribute(:miq_group_id))

      t.grouping(group_tbl.project(group_sel).where(where_cond))
    end)
  end

  module ClassMethods
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
        user_owned(user).or(group_owned(miq_group))
      elsif user
        user_owned(user)
      elsif miq_group
        group_owned(miq_group)
      else
        none
      end
    end

    private

    def user_owned(user)
      where(arel_table.grouping(Arel::Nodes::NamedFunction.new("LOWER", [arel_attribute(:evm_owner_userid)]).eq(user.userid)))
    end

    def group_owned(miq_group)
      where(:miq_group_id => miq_group.id)
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
