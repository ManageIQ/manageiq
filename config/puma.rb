# We run puma through rails server with options here:
# https://github.com/ManageIQ/manageiq/blob/2920f76fe609147a6e7c68245a3717d55a7ece7e/app/models/mixins/miq_web_server_worker_mixin.rb#L162-L175
#
# Note, Rails::Server and Rack::Server don't expose all puma web server options.
#
# As of puma 3.0.0+, puma specific options can be put in config/puma.rb, see:
# https://github.com/puma/puma/tree/a3136985887d44c79e623b1408a41779b71d8b23#configuration
#
#
# For each rack request, Rails' query cache middleware reserves a database connection
# for the current thread:
# https://github.com/rails/rails/blob/fa3537506a12635b51886919589211640ddd3a15/activerecord/lib/active_record/query_cache.rb#L28
#
# Puma spins up a thread for each request.
#
# Therefore, we should have a database.yml pool greater than or equal to the puma
# thread count or we risk a ActiveRecord::ConnectionTimeoutError waiting on a
# connection from the connection pool.
#
threads(5, 5)
tag("MIQ: Web Server Worker")
