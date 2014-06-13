module ActiveRecord
  class Base
    class << self
      delegate :with_connection, :to => :connection_pool
    end
  end
end
