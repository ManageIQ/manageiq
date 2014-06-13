class VimPerformanceTagDaily < VimPerformanceTag
  def self.instances_are_derived?
    true
  end

  def self.find_and_group_by_tags(options)
    raise "no catagory provided" if options[:category].blank?
    self.group_by_tags(VimPerformanceDaily.find(:all, :conditions => options[:where_clause], :ext_options => options[:ext_options]), options)
  end
end
