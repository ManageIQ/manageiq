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

  def record_name(rec)
    column = rec.display_name.blank? ? :name : :display_name
    rec_name = if rec.kind_of?(MiqAeNamespace) && rec.domain? && (!rec.editable? || !rec.enabled)
                 add_read_only_suffix(rec, rec.send(column))
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
    when "MiqAeNamespace"
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
