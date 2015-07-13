namespace :test do
  namespace :javascript do
    task :setup => :setup_db
  end

  desc "Run all javascript specs"
  task :javascript => [:initialize, :environment, "jasmine:ci"]
end
