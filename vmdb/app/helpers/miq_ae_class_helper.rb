module MiqAeClassHelper
  def add_read_only_suffix(node_string)
    "#{node_string} (Locked)"
  end

  def domain_display_name(domain)
    @record.fqname.split('/').first == domain.name ? "#{domain.name} (Same Domain)" : domain.name
  end
end
