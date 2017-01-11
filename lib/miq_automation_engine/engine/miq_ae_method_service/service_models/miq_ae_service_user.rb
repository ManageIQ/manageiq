module MiqAeMethodService
  class MiqAeServiceUser < MiqAeServiceModelBase
    require_relative "mixins/miq_ae_service_custom_attribute_mixin"
    include MiqAeServiceCustomAttributeMixin

    expose :current_group,  :association => true
    expose :current_tenant, :association => true
    expose :vms,            :association => true
    expose :miq_groups,     :association => true
    expose :miq_requests,   :association => true
    expose :name
    expose :email
    expose :userid
    expose :ldap_group

    def role
      ar_method { @object.role.nil? ? nil : @object.role.name }
    end

    def get_ldap_attribute_names
      ar_method do
        ldap_user = find_ldap_user
        ldap_user.attribute_names
      end
    end

    def get_ldap_attribute(name)
      ar_method do
        ldap_user = find_ldap_user
        value     = MiqLdap.get_attr(ldap_user, name.to_sym)
        value.nil? ? nil : value.dup
      end
    end

    def miq_group
      $miq_ae_logger.warn("[DEPRECATION] #{self.class.name}#miq_group accessor is deprecated.  Please use current_group instead.  At #{caller[0]}")
      current_group
    end

    private

    def find_ldap_user
      ldap = MiqLdap.new
      raise "Cannot bind to LDAP with system defaults (see evm.log for details)" if ldap.bind_with_default == false
      ldap_user = ldap.get_user_object(@object.email, 'mail') || ldap.get_user_object(@object.userid, 'userprincipalname')
      raise "No information returned for email=<#{@object.email}> userid=<#{@object.userid}>" if ldap_user.nil?
      ldap_user
    end
  end
end
