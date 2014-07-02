
namespace :test do
  namespace :coverage do
    desc "Delete aggregate coverage data."
    task(:clean) { rm_f "coverage.data" }
  end

  desc 'Aggregate code coverage for unit, functional and integration tests'
  task :coverage => "test:coverage:clean"
  begin
    require 'rcov'
    require 'rcov/rcovtask'
    # need to add integration/functional
    %w[unit].each do |target|
      namespace :coverage do
        Rcov::RcovTask.new(target) do |t|
          t.libs << "test"
          t.test_files = FileList["test/#{target}/*_test.rb"]
          t.output_dir = File.join(ENV['CC_BUILD_ARTIFACTS'], "coverage") if ENV['CC_BUILD_ARTIFACTS'] != nil
          t.verbose = false
          if target == "unit"
            t.rcov_opts = ['--rails --aggregate coverage.data --text-report --sort coverage --no-html']
          else
            t.rcov_opts = ['--rails --aggregate coverage.data --no-html --text-summary']
          end
        end
      end
      task :coverage => "test:coverage:#{target}"
    end
  rescue LoadError
#    rcov may not be available
  end
end
