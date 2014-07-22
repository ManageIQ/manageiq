class Dictionary
  def self.gettext(text, opts = {})
    opts[:type] ||= :column

    key, suffix = text.split("__")  # HACK: Sometimes we need to add a suffix to report columns, this should probably be moved into the presenter.
    result      = i18n_lookup(opts[:type], key)
    result    ||= i18n_lookup(opts[:type], key.split(".").last)
    result     << " (#{suffix.titleize})" if result && suffix  # HACK: continued.  i.e. Adding (Min) or (Max) to a column name.

    return result if result
    return text unless opts[:notfound]

    col = text.split(".").last

    # HACK: Strip off the 'v_' for virtual columns if titleizing
    col = col[2..-1] if col.starts_with?("v_") && opts[:notfound].to_sym == :titleize

    col.send(opts[:notfound])
  end

  def self.i18n_lookup(type, text)
    result = I18n.t("dictionary.#{type}.#{text}")
    result.start_with?("translation missing:") ? nil : result
  end
  private_class_method :i18n_lookup
end
