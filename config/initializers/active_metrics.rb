# Note: The legacy Postgresql adapter ignores everything except the adapter name here, just stealing the current ActiveRecord connection.
ActiveMetrics::Base.establish_connection(:adapter => "miq_postgres", :database => "manageiq_metrics")
