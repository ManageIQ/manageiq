class VimPerformanceTagDaily < VimPerformanceTag
  def self.instances_are_derived?
    true
  end

  def self.find_and_group_by_tags(options)
    raise _("no catagory provided") if options[:category].blank?
    group_by_tags(VimPerformanceDaily.find_entries(options[:ext_options]).where(options[:where_clause]), options)
  end
end
