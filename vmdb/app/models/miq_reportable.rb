module MiqReportable
  # generate a ruport table from an array of db objects
  def self.records2table(records, options)
    return Ruport::Data::Table.new if records.blank?

    data = records.map {|r|
      options[:include]["categories"] = options[:include_categories] if options[:include] && options[:include_categories]
      r.reportable_data(:include => options[:include],
                             :only => options[:only],
                             :except => options[:except],
                             :tag_filters => options[:tag_filters],
                             :methods => options[:methods])
    }.flatten

    data = data[0..options[:limit] - 1] if options[:limit] # apply limit after includes are processed
    Ruport::Data::Table.new(:data => data,
                            :column_names => [],
                            :record_class => options[:record_class],
                            :filters => options[:filters])
  end

  # generate a ruport table from an array of hashes where the keys are the column names
  def self.hashes2table(hashes, options)
    return Ruport::Data::Table.new if hashes.blank?

    data = hashes.inject([]) do |arr,h|
      nh = {}
      options[:only].each { |col| nh[col] = h[col] }
      arr << nh
    end

    data = data[0..options[:limit] - 1] if options[:limit] # apply limit
    Ruport::Data::Table.new(:data => data,
                            :column_names => options[:only],
                            :filters => options[:filters])
  end
end
