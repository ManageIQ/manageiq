require 'thread'

# Ensure that when a thread completes it makes the connection available for the next new thread
# in the same process and thereby reduces the total number of open SQL connections held by the
# connection pool.

class << Thread
  def new_with_release(*args)
    new_without_release do
      begin
        yield(*args)
      ensure
        ActiveRecord::Base.connection_pool.release_connection rescue nil
      end
    end
  end
  alias_method_chain :new, :release

  def start_with_release(*args)
    start_without_release do
      begin
        yield(*args)
      ensure
        ActiveRecord::Base.connection_pool.release_connection rescue nil
      end
    end
  end
  alias_method_chain :start, :release

  alias fork start
end
