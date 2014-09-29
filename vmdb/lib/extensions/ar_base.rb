module ActiveRecord
  class Base

    # Truncates the table.
    #
    # ==== Example
    #
    #   Post.truncate
    def truncate
      connection.truncate(table_name, "#{name} Truncate")
    end
  end
end
