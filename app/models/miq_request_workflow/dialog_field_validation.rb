# These methods are available for dialog field validation, do not erase.
module MiqRequestWorkflow::DialogFieldValidation
  def validate_tags(field, values, _dlg, fld, _value)
    selected_tags_categories = values[field].to_miq_a.collect do |tag_id|
      Classification.find_by(:id => tag_id).parent.name.to_sym
    end

    required_tags = fld[:required_tags].to_miq_a.collect(&:to_sym)
    missing_tags = required_tags - selected_tags_categories
    missing_categories_names = missing_tags.collect do |category|
      Classification.find_by_name(category.to_s).description rescue nil
    end.compact

    return nil if missing_categories_names.blank?
    _("Required tag(s): %{names}") % {:names => missing_categories_names.join(', ')}
  end

  def validate_length(_field, _values, dlg, fld, value)
    return _("%{name} is required") % {:name => required_description(dlg, fld)} if value.blank?
    if fld[:min_length] && value.to_s.length < fld[:min_length]
      return _("%{name} must be at least %{length} characters") % {:name   => required_description(dlg, fld),
                                                                   :length => fld[:min_length]}
    end
    if fld[:max_length] && value.to_s.length > fld[:max_length]
      return _("%{name} must not be greater than %{length} characters") % {:name   => required_description(dlg, fld),
                                                                           :length => fld[:max_length]}
    end
  end

  def validate_regex(_field, _values, dlg, fld, value)
    regex = fld[:required_regex]
    return _("%{name} is required") % {:name => required_description(dlg, fld)} if value.blank?
    unless value.match(regex)
      error = _("%{name} must be correctly formatted") % {:name => required_description(dlg, fld)}
      error << _(". %{details}") % {:details => fld[:required_regex_fail_details] } if fld[:required_regex_fail_details]

      error
    end
  end
end
