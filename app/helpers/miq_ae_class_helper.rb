module MiqAeClassHelper
  def editable_domain?(record)
    record.editable?
  end

  def git_enabled?(record)
    record.class == MiqAeDomain && record.git_enabled?
  end

  def add_read_only_suffix(node_string, editable, enabled)
    if enabled && !editable
      suffix = "Locked"
    elsif editable && !enabled
      suffix = "Disabled"
    else # !rec.enabled && !rec.editable?
      suffix = "Locked & Disabled"
    end
    "#{node_string} (#{suffix})".html_safe
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

  def record_name(rec)
    column   = rec.display_name.blank? ? :name : :display_name
    rec_name = if rec.kind_of?(MiqAeNamespace) && rec.domain?
                 editable_domain?(rec) && rec.enabled ? rec.send(column) : add_read_only_suffix(rec.send(column),
                                                                                                editable_domain?(rec),
                                                                                                rec.enabled)
               else
                 rec.send(column)
               end
    rec_name = rec_name.gsub(/\n/, "\\n")
    rec_name = rec_name.gsub(/\t/, "\\t")
    rec_name = rec_name.tr('"', "'")
    rec_name = CGI.escapeHTML(rec_name)
    rec_name.gsub(/\\/, "&#92;")
  end

  def class_prefix(cls)
    case cls.to_s.split("::").last
    when "MiqAeClass"
      "aec"
    when "MiqAeDomain", "MiqAeNamespace"
      "aen"
    when "MiqAeInstance"
      "aei"
    when "MiqAeField"
      "Field"
    when "MiqAeMethod"
      "aem"
    end
  end

  def icon_class(cls)
    cls.to_s.split("::").last.underscore.sub('miq_', 'product product-')
  end

  def nonblank(*items)
    items.detect { |item| !item.blank? }
  end
end
