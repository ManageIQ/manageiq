module OwnershipMixin
  extend ActiveSupport::Concern

  included do
    before_validation :set_tenant_from_group

    belongs_to :evm_owner, :class_name => "User"
    belongs_to :miq_group

    virtual_delegate :email, :name, :userid, :to => :evm_owner, :prefix => true, :allow_nil => true, :type => :string

    # Determine whether the selected object is owned by the current user
    # Resulting SQL:
    #
    #   (LOWER((SELECT "users"."userid"
    #           FROM "users"
    #           WHERE "users"."id" = "THIS_MODELS_TABLE"."evm_owner_id")) = 'some_userid')
    #
    # explination:
    # At first it looks like a simple compare with evm_owner_id = current user id would suffice.
    #   i.e.: t.grouping(arel_attribute(:evm_owner_id)]).eq(User.current_user.try(:id)))
    #
    # But the code is written to support the same userid used across multiple regions. Assuming that they are
    # all the same user.
    virtual_attribute :owned_by_current_user, :boolean, :uses => :evm_owner, :arel => (lambda do |t|
      userid = User.current_userid.to_s.downcase
      t.grouping(Arel::Nodes::NamedFunction.new("LOWER", [arel_attribute(:evm_owner_userid)]).eq(userid))
    end)

    virtual_delegate :owning_ldap_group, :to => "miq_group.description", :allow_nil => true, :type => :string

    # Determine whether to return objects owned by the current user's miq_group
    # or not.
    #
    # Resulting SQL:
    #
    #   (LOWER((SELECT "miq_groups"."description"
    #           FROM "miq_groups"
    #           WHERE "miq_groups"."id" = "THIS_MODELS_TABLE"."miq_group_id")) = 'some_miq_group')
    #
    # Will result in the following when used with MiqExpression:
    #
    #   WHERE (LOWER((SELECT "miq_groups"."description"
    #                 FROM "miq_groups"
    #                 WHERE "miq_groups"."id" = "THIS_MODELS_TABLE"."miq_group_id")) = 'some_miq_group') = 'true'
    virtual_attribute :owned_by_current_ldap_group, :boolean, :arel => (lambda do |t|
      ldap_group = User.current_user.try(:ldap_group).to_s.downcase

      t.grouping(Arel::Nodes::NamedFunction.new("LOWER", [arel_attribute(:owning_ldap_group)]).eq(ldap_group))
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
      where(arel_table.grouping(Arel::Nodes::NamedFunction.new("LOWER", [arel_attribute(:evm_owner_userid)]).eq(user.userid.downcase)))
    end

    def group_owned(miq_group)
      where(arel_table.grouping(Arel::Nodes::NamedFunction.new("LOWER", [arel_attribute(:owning_ldap_group)]).eq(miq_group.description.downcase)))
    end
  end

  def owned_by_current_user
    User.current_userid && evm_owner_userid && User.current_userid.downcase == evm_owner_userid.downcase
  end

  def owned_by_current_ldap_group
    ldap_group = User.current_user.try(:ldap_group)
    ldap_group && owning_ldap_group && (owning_ldap_group.downcase == ldap_group.downcase)
  end

  def set_tenant_from_group
    self.tenant_id = miq_group.tenant_id if miq_group
  end
end
