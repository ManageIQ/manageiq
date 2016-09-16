module Spec
  module Support
    module RakeTaskExampleGroup
      extend ActiveSupport::Concern

      included do
        let(:rake) { Rake::Application.new }

        before do
          Rake.application = rake
          Rake.application.rake_require(task_path, [Rails.root.to_s], [Rails.root.join("#{task_path}.rake").to_s])

          Rake::Task.define_task(:environment)
        end
      end
    end
  end
end
