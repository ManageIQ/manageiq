module TreeNode
  class LdapDomain < Node
    set_attribute(:title) { _("Domain: %{domain_name}") % {:domain_name => @object.name} }
    set_attribute(:image, '100/ldap_domain.png')
    set_attribute(:tooltip) { _("LDAP Domain: %{ldap_domain_name}") % {:ldap_domain_name => @object.name} }
  end
end
