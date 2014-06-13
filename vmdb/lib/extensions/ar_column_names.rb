module ActiveRecord
  class Base
    def self.column_names_symbols
      @column_names_symbols ||= self.column_names.collect { |c| c.to_sym }
    end
  end
end
