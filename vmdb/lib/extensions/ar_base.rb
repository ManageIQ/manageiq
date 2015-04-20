module ActiveRecord
  class Base
    include Vmdb::NewLogging

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
