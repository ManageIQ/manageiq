require_relative "./evm_test_helper"

if defined?(RSpec) && defined?(RSpec::Core::RakeTask)
namespace :test do
  specs = {
    automation: 149,   # automation
    controllers: 1274, # controllers
    helpers: 1005,     # ui
    initializers: 1,   # others
    lib: 1283,         # lib
    mailers: 19,       # lib
    migrations: 321,   # migrations
    models: 4494,      # models
    presenters: 122,   # ui
    replication: 2,    # replication
    requests: 797,     # others
    routing: 1769,     # routing
    services: 122,     # others
    task_helpers: 4,   # others
    tools: 46,         # others
    views: 65,         # ui
  }
  namespace :vmdb_controllers do
    desc "Setup environment for vmdb specs"
    task :setup => [:initialize, :verify_no_db_access_loading_rails_environment, :setup_db]

    task :teardown
  end

  desc "Run all core specs (excludes automation, migrations, replication, etc)"
  RSpec::Core::RakeTask.new(:vmdb_controllers => [:initialize, "evm:compile_sti_loader"]) do |t|
    EvmTestHelper.init_rspec_task(t)
    t.pattern = FileList["spec/{controllers}/**/*_spec.rb"]
  end

  namespace :vmdb_ui do
    desc "Setup environment for vmdb specs"
    task :setup => [:initialize, :verify_no_db_access_loading_rails_environment, :setup_db]
  end

  desc "Run all core specs (excludes automation, migrations, replication, etc)"
  RSpec::Core::RakeTask.new(:vmdb_ui => [:initialize, "evm:compile_sti_loader"]) do |t|
    EvmTestHelper.init_rspec_task(t)
    t.pattern = FileList["spec/{helpers,presenters,views}/**/*_spec.rb"]
  end

  namespace :vmdb_lib do
    desc "Setup environment for vmdb specs"
    task :setup => [:initialize, :verify_no_db_access_loading_rails_environment, :setup_db]
  end

  desc "Run all core specs (excludes automation, migrations, replication, etc)"
  RSpec::Core::RakeTask.new(:vmdb_lib => [:initialize, "evm:compile_sti_loader"]) do |t|
    EvmTestHelper.init_rspec_task(t)
    t.pattern = FileList["spec/{lib}/**/*_spec.rb"]
  end

  namespace :vmdb_others do
    desc "Setup environment for vmdb specs"
    task :setup => [:initialize, :verify_no_db_access_loading_rails_environment, :setup_db]
  end

  desc "Run all core specs (excludes automation, migrations, replication, etc)"
  RSpec::Core::RakeTask.new(:vmdb_others => [:initialize, "evm:compile_sti_loader"]) do |t|
    EvmTestHelper.init_rspec_task(t)
    t.pattern = FileList["spec/{initializers,mailers,requests,services,task_helpers,tools}/**/*_spec.rb"]
  end

  namespace :vmdb_routing do
    desc "Setup environment for vmdb specs"
    task :setup => [:initialize, :verify_no_db_access_loading_rails_environment, :setup_db]
  end

  desc "Run all core specs (excludes automation, migrations, replication, etc)"
  RSpec::Core::RakeTask.new(:vmdb_routing => [:initialize, "evm:compile_sti_loader"]) do |t|
    EvmTestHelper.init_rspec_task(t)
    t.pattern = FileList["spec/{routing}/**/*_spec.rb"]
  end

  namespace :vmdb_models do
    desc "Setup environment for vmdb specs"
    task :setup => [:initialize, :verify_no_db_access_loading_rails_environment, :setup_db]
  end

  desc "Run all core specs (excludes automation, migrations, replication, etc)"
  RSpec::Core::RakeTask.new(:vmdb_models => [:initialize, "evm:compile_sti_loader"]) do |t|
    EvmTestHelper.init_rspec_task(t)
    t.pattern = FileList["spec/models/**/*_spec.rb"].exclude(/^spec\/models\/manageiq\/providers/)
  end

  namespace :vmdb_providers do
    desc "Setup environment for vmdb specs"
    task :setup => [:initialize, :verify_no_db_access_loading_rails_environment, :setup_db]
  end

  desc "Run all core specs (excludes automation, migrations, replication, etc)"
  RSpec::Core::RakeTask.new(:vmdb_providers => [:initialize, "evm:compile_sti_loader"]) do |t|
    EvmTestHelper.init_rspec_task(t)
    t.pattern = FileList["spec/models/manageiq/providers/**/*_spec.rb"]
  end
end
end # ifdef
