# Monkey patched version of sort_rows_by from ruport (1.2.0) gem
# => Force case insensitive sort.
# => Enable sorting of booleans.
#
require 'ruport'
module Ruport::Data
  class Table
    def sort_rows_by(col_names = nil, options = {}, &block)
      self.class.new(:data         => stable_sort_by(col_names, options[:order], &block),
                     :column_names => @column_names,
                     :record_class => record_class)
    end
  end
end
