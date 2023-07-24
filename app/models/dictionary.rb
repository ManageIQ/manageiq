class Dictionary
  def self.gettext(text, opts = {})
    return "" if text.blank?

    opts[:type] ||= :column
    opts[:plural] = false if opts[:plural].nil?
    opts[:translate] = true if opts[:translate].nil?

    key, suffix = text.split("__")  # HACK: Sometimes we need to add a suffix to report columns, this should probably be moved into the presenter.

    i18n_result = i18n_lookup(opts[:type], key)
    i18n_result ||= i18n_lookup(opts[:type], key.split(".").last)
    i18n_result = if i18n_result && opts[:plural]
                    m = /(.+)(\s+\(.+\))/.match(i18n_result)
                    m ? "#{m[1].pluralize}#{m[2]}" : i18n_result.pluralize
                  else
                    i18n_result
                  end

    result = if i18n_result
               opts[:translate] ? _(i18n_result) : i18n_result
             end

    result << " (#{suffix.titleize})" if result && suffix  # HACK: continued.  i.e. Adding (Min) or (Max) to a column name.

    return result if result
    return text unless opts[:notfound]

    col = text.split(".").last

    # HACK: Strip off the 'v_' for virtual columns if titleizing
    col = col[2..-1] if col.starts_with?("v_") && opts[:notfound].to_sym == :titleize

    opts[:plural] ? col.send(opts[:notfound]).send(:pluralize) : col.send(opts[:notfound])
  end

  def self.ui_lookup(options = {})
    if options[:table]
      gettext(options[:table], :type => :table, :notfound => :titleize, :plural => false)
    elsif options[:tables]
      gettext(options[:tables], :type => :table, :notfound => :titleize, :plural => true)
    elsif options[:model]
      gettext(options[:model], :type => :model, :notfound => :titleize, :plural => false)
    elsif options[:models]
      gettext(options[:models], :type => :model, :notfound => :titleize, :plural => true)
    elsif options[:ui_title]
      gettext(options[:ui_title], :type => :ui_title)
    else
      ''
    end
  end

  def self.i18n_lookup(type, text)
    result = I18n.t("dictionary.#{type}.#{text}", :locale => "en")
    result if result && !result.match?(/Translation missing:/i)
  end
  private_class_method :i18n_lookup
end
