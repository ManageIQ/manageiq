if defined?(RSpec) && defined?(RSpec::Core::RakeTask)
  namespace :test do
    namespace 'manageiq-providers-amazon' do
      desc "Setup environment for amazon specs"
      task :setup => [:initialize, :verify_no_db_access_loading_rails_environment, :setup_db]
    end

    desc "Run all amazon specs"
    RSpec::Core::RakeTask.new('manageiq-providers-amazon' => [:initialize, "evm:compile_sti_loader"]) do |t|
      EvmTestHelper.init_rspec_task(t)
      t.pattern = FileList['gems/manageiq-providers-amazon/spec/**/*_spec.rb']
    end
  end
end # ifdef
