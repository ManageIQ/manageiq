class VimPerformanceTagDaily < VimPerformanceTag
  def self.instances_are_derived?
    true
  end

  def self.find_and_group_by_tags(options)
    raise _("no catagory provided") if options[:category].blank?
    ext_options = options[:ext_options] || {}
    entries = Metric::Helper.find_for_interval_name("daily", ext_options[:time_profile] || ext_options[:tz],
                                                    ext_options[:class])
                            .where(options[:where_clause])
    group_by_tags(entries, options)
  end
end
