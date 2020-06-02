# Monkey patched version of sort_rows_by from ruport (1.2.0) gem
# => Force case insensitive sort.
# => Enable sorting of booleans.
#
require 'ruport'
module Ruport::Data
  class Table
    def sort_rows_by(col_names = nil, options = {}, &block)
      self.class.new(:data         => to_a.tabular_sort(col_names, options[:order], &block),
                     :column_names => @column_names,
                     :record_class => record_class)
    end
  end
end

module Ruport

  # Handles preventing CSV injection attacks by adding an apostrophe to all
  # fields that could potentially be a formula that executes a function.
  #
  # This targets values that both:
  #
  #   - Start with '=', '+', '-', or '@' characters
  #   - Include a '(' or '!' in them
  #
  # Either of which could be executing a particular function, but still retains
  # some features of simple arithmatic operations of speadsheets if users
  # happen to be using them, as well as not mucking with "negative numbers" for
  # just using the raw CSV in a scripting language like Ruby/Python.
  #
  class Formatter::SafeCSV < Formatter::CSV
    renders :csv, :for => [ Controller::Row,   Controller::Table,
                            Controller::Group, Controller::Grouping ]

    def build_table_body
      data.each do |row|
        row_data = row.map do |column_value|
          column_value.insert(0, "'") if column_value =~ /^\s*[@=+-]/ && column_value =~ /[(!\/]/
          column_value
        end

        csv_writer << row_data
      end
    end
  end
end
