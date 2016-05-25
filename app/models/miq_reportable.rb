module MiqReportable
  # generate a ruport table from an array of db objects
  def self.records2table(records, only_columns)
    return Ruport::Data::Table.new if records.blank?

    data_records = records.map do |r|
      only_columns.each_with_object({}) do |column, attrs|
        attrs[column] = r.send(column) if r.respond_to?(column)
      end
    end

    column_names = data_records.flat_map(&:keys).uniq

    Ruport::Data::Table.new(:data         => data_records,
                            :column_names => column_names)
  end

  # generate a ruport table from an array of hashes where the keys are the column names
  def self.hashes2table(hashes, options)
    return Ruport::Data::Table.new if hashes.blank?

    data = hashes.inject([]) do |arr, h|
      nh = {}
      options[:only].each { |col| nh[col] = h[col] }
      arr << nh
    end

    data = data[0..options[:limit] - 1] if options[:limit] # apply limit
    Ruport::Data::Table.new(:data         => data,
                            :column_names => options[:only],
                            :filters      => options[:filters])
  end
end
