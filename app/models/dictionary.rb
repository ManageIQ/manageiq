class Dictionary
  def self.gettext(text, opts = {})
    opts[:type] ||= :column
    opts[:plural] ||= false

    key, suffix = text.split("__")  # HACK: Sometimes we need to add a suffix to report columns, this should probably be moved into the presenter.

    i18n_result = i18n_lookup(opts[:type], key)
    i18n_result ||= i18n_lookup(opts[:type], key.split(".").last)
    result = _(opts[:plural] ? i18n_result.pluralize : i18n_result) if i18n_result
    result << " (#{suffix.titleize})" if result && suffix  # HACK: continued.  i.e. Adding (Min) or (Max) to a column name.

    return result if result
    return text unless opts[:notfound]

    col = text.split(".").last

    # HACK: Strip off the 'v_' for virtual columns if titleizing
    col = col[2..-1] if col.starts_with?("v_") && opts[:notfound].to_sym == :titleize

    opts[:plural] ? col.send(opts[:notfound]).send(:pluralize) : col.send(opts[:notfound])
  end

  def self.i18n_lookup(type, text)
    result = I18n.t("dictionary.#{type}.#{text}")
    result.start_with?("translation missing:") ? nil : result
  end
  private_class_method :i18n_lookup
end
