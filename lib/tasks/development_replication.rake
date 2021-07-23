namespace :development do
  namespace :replication do
    desc "Manually setup logical replication locally"
    task :setup => :environment do
      TaskHelpers::Development::Replication.backup
      TaskHelpers::Development::Replication.setup
    end

    task :teardown => :environment do
      TaskHelpers::Development::Replication.teardown
    end
  end
end
