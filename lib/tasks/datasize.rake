# https://gist.github.com/296719
namespace :db do
  desc 'Print data size for entire database'
  task :size => :environment do
    database_name = ActiveRecord::Base.connection.instance_variable_get("@config")[:database]
    sql = "SELECT pg_size_pretty(pg_database_size('#{database_name}'));"
    puts ActiveRecord::Base.connection.execute(sql)[0]["pg_size_pretty"]
  end

  namespace :tables do
    desc 'Print data size for all tables'
    task :size => :environment do
      sql = "SELECT tablename FROM pg_tables WHERE schemaname = 'public' ORDER BY tablename;"
      tables = ActiveRecord::Base.connection.execute(sql)
      tables.each do |table|
        name = table['tablename']
        sql = "SELECT pg_size_pretty(pg_total_relation_size('#{name}'));"
        res = ActiveRecord::Base.connection.execute(sql)
        puts "#{name}: #{res[0]['pg_size_pretty']}"
      end
    end
  end
end
