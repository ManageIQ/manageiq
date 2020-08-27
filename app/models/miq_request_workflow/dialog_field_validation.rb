# These methods are available for dialog field validation, do not erase.
module MiqRequestWorkflow::DialogFieldValidation
  def validate_tags(field, values, _dlg, fld, _value)
    selected_tags_categories = Array.wrap(values[field].split('\n')).collect do |tag_id|
      Classification.find_by(:id => tag_id).parent.name.to_sym
    end

    required_tags = Array.wrap(fld[:required_tags].presence).collect(&:to_sym)
    missing_tags = required_tags - selected_tags_categories
    missing_categories_names = missing_tags.collect do |category|
      begin
        Classification.lookup_by_name(category.to_s).description
      rescue StandardError
        nil
      end
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

  def validate_blacklist(_field, _values, dlg, fld, value)
    blacklist = fld[:blacklist]
    return _("%{name} is required") % {:name => required_description(dlg, fld)} if value.blank?
    if blacklist && blacklist.include?(value)
      _("%{name} may not contain blacklisted value") % {:name => required_description(dlg, fld)}
    end
  end
end
