module ActiveRecord
  class Base
    include Vmdb::Logging

    # Truncates the table.
    #
    # ==== Example
    #
    #   Post.truncate
    def self.truncate
      connection.truncate(table_name, "#{name} Truncate")
    end

  end
end
