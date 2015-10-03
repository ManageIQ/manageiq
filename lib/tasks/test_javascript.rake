namespace :test do
  namespace :javascript do
    desc "Setup environment for javascript specs"
    task :setup => :setup_db
  end

  desc "Run all javascript specs"
  task :javascript => [:initialize, :environment, "jasmine:ci"]
end
