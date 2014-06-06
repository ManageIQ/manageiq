namespace :test do
  Rake::TestTask.new(:lib) do |t|
    t.libs << "lib"
    t.libs << "test"
    t.pattern = 'test/lib/**/*_test.rb'
  end
  Rake::Task['test:lib'].comment = "Run the tests in test/lib"
end
