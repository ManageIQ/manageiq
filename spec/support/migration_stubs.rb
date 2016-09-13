module Spec
  module Support
    module MigrationStubs
      def self.reserved_stub
        Class.new(ActiveRecord::Base) do
          self.table_name = "reserves"
          self.inheritance_column = :_type_disabled # disable STI
          serialize :reserved
        end
      end
    end
  end
end
