module ActiveRecord
  class Base
    def self.column_names_symbols
      @column_names_symbols ||= column_names.collect(&:to_sym)
    end
  end
end
