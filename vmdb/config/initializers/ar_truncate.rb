if ActiveRecord::Base.connection.respond_to? :truncate
  puts "Rails is new enough to have truncate, please remove this: #{__FILE__}"
else
  class << ActiveRecord::Base.connection.class
    def truncate(table_name, name = nil)
      execute("TRUNCATE TABLE #{quote_table_name(table_name)}", name)
    end
  end
end
