
# uncomment to run through ruby (otherwise you must run through script/runner)
#require File.expand_path(File.join(File.dirname(__FILE__), '..', 'test_helper'))


require 'test/unit'
require 'active_record'
require 'dbi'
require 'postgres'

class DBConnectionTest < ActiveSupport::TestCase

  def test_connection
    threads = []
    ActiveRecord::Base.connection.disconnect!
    assert_nothing_raised do
      10.times do
        t = Thread.new do
          3.times do
            ActiveRecord::Base.connection.select_all("SELECT * FROM hosts")
          end
        end
        threads.push(t)
      end
      threads.each {|t| t.join}
    end
  end

end

#   If you need to establish a connection other than the one available through script runner,
#   put this in the DBConn class
#    establish_connection(
#      :adapter =>   "sqlserver",
#      :mode =>      "odbc",
#      :host =>      "localhost",
#      :dsn =>       "DB_CONNECTION",
#      :username =>  "user",
#      :password =>  "pass"
#    )
