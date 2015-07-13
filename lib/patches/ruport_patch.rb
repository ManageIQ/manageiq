# Monkey patched version of sort_rows_by from ruport (1.2.0) gem
# => Force case insensitive sort.
# => Enable sorting of booleans.
#
require 'ruport'
module Ruport::Data
  class Table
    def sort_rows_by(col_names=nil, options={}, &block)
      # stabilizer is needed because of
      # http://blade.nagaokaut.ac.jp/cgi-bin/scat.rb/ruby/ruby-talk/170565
      stabilizer = 0
      nil_rows, sortable = partition do |r|
        Array(col_names).any? { |c| r[c].nil? }
      end

      data_array =
        if col_names
          sortable.sort_by do |r|
            stabilizer += 1
            [Array(col_names).map {|col|
              val = r[col]
              val = val.downcase if val.is_a?(String)
              val = val.to_s     if val.is_a?(FalseClass) || val.is_a?(TrueClass)
              val
            }, stabilizer]
          end
        else
          sortable.sort_by(&block)
        end

      data_array += nil_rows
      data_array.reverse! if options[:order] == :descending

      table = self.class.new( :data => data_array,
                              :column_names => @column_names,
                              :record_class => record_class )

      return table
    end
  end
end
