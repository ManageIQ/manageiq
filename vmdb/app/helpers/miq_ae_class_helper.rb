module MiqAeClassHelper
  def add_read_only_suffix(rec, node_string)
    if rec.enabled && !rec.editable?
      suffix = "Locked"
    elsif rec.editable? && !rec.enabled
      suffix = "Disabled"
    else # !rec.enabled && !rec.editable?
      suffix = "Locked & Disabled"
    end
    "#{node_string} (#{suffix})"
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
