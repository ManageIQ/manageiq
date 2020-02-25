module ManageIQ
  module Reporting
    module Formatter
      class Converter
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
    end
  end
end
