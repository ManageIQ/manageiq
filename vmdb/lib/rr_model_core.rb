module RrModelCore
  extend ActiveSupport::Concern

  included do
    self.table_name = table_name_for(self.my_region_number)
  end

  module ClassMethods
    def table_name_for(region_number)
      "rr#{region_number}_#{self::RR_TABLE_NAME_SUFFIX}"
    end

    def for_region_number(region_number)
      raise "no block given" unless block_given?
      orig_table_name = self.table_name

      begin
        self.table_name = table_name_for(region_number)
        yield
      ensure
        self.table_name = orig_table_name
      end
    end
  end
end
