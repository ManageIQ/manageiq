module MiqAeClassHelper
  def add_read_only_suffix(node_string)
    "#{node_string} (Locked)"
  end

  def domain_display_name(domain)
    @record.fqname.split('/').first == domain.name ? "#{domain.name} (Same Domain)" : domain.name
  end

  def domain_display_name_using_name(record, current_domain_name)
    domain_name = record.domain.name
    if domain_name == current_domain_name
      return "#{domain_name} (Same Domain)", nil
    else
      return domain_name, record.id
    end
  end
end
