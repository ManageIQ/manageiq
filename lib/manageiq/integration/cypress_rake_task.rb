require "rake/tasklib"

module ManageIQ
  module Integration
    # A Rake TaskLib for building tasks to run cypress for a given manageiq plugin
    #
    # When defining, provide a namespace, usually indicative of the plugin you
    # are testing, and if needed, you can override the @ui_engine_root
    #
    class CypressRakeTask < Rake::TaskLib

      # Namespace for the cypress tasks to live under
      attr_accessor :cypress_namespace

      # Root directory location for ManageIQ::UI::Classic
      attr_accessor :ui_engine_root

      def initialize(cypress_namespace)
        @cypress_namespace = cypress_namespace
        @ui_engine_root    = ManageIQ::UI::Classic::Engine.root

        yield self if block_given?

        define
      end

      def define
        namespace :cypress do
          desc "Run cypress #{cypress_namespace} tests"
          task cypress_namespace => ":#{cypress_namespace}run"

          define_cypress_namespace
        end
      end

      private

      def define_cypress_namespace
        namespace cypress_namespace do
          desc "Seed database/configure assets for cypress specs"
          task :seed do
            Rake::Task["#{app_prefix}integration:seed"].invoke
          end

          desc "Interactively run cypress tests"
          task :open => ["#{cypress_namespace}:setup"] do
            sh "#{yarn_cmd} cypress:open"
          end

          desc "Run headless cypress tests"
          task :run, [:spec_file] => ["#{cypress_namespace}:setup"] do |t, args|
            args.with_defaults :spec_file => nil

            cmd  = "#{yarn_cmd} cypress:run:ci"
            cmd << " --spec #{args.spec_file}" if args.spec_file

            sh cmd
          end

          desc "Stop the backend Rails server"
          task :stop do
            Rake::Task["#{app_prefix}integration:stop_server"].invoke
          end

          task :setup => cypress_env_file do
            Rake::Task["#{app_prefix}integration:start_server"].invoke
          end

          define_cypress_env_file_task
          define_cypress_dev_tasks
        end
      end

      def define_cypress_env_file_task
        file cypress_env_file do |cypress_env_json_file|
          unless File.exist?(cypress_env_file)
            cypress_dir         = File.dirname(cypress_env_file)
            cypress_env_example = ".cypress.dev.env.json"
            cypress_env_example = ".cypress.ci.env.json" if ENV["CI"] || ENV["TRAVIS"]

            cp File.join(cypress_dir, cypress_env_example), cypress_env_json_file.name
          end
        end
      end

      def define_cypress_dev_tasks
        desc "Run cypress tests in 'development' mode"
        task :dev => "dev:run"

        # Aliases for running with CYPRESS_DEV
        namespace :dev do
          desc "'Development Mode' for cypress:#{cypress_namespace}:seed"
          task :seed => [:env, "cypress:#{cypress_namespace}:seed"]

          desc "'Development Mode' for cypress:#{cypress_namespace}:open"
          task :open => [:env, "cypress:#{cypress_namespace}:open"]

          desc "'Development Mode' for cypress:#{cypress_namespace}:run"
          task :run => [:env, "cypress:#{cypress_namespace}:run"]

          desc "'Development Mode' for cypress:#{cypress_namespace}:setup"
          task :setup => [:env, "cypress:#{cypress_namespace}:setup"]

          desc "'Development Mode' for cypress:#{cypress_namespace}:stop"
          task :stop => [:env, "cypress:#{cypress_namespace}:stop"]

          # Helper task to defaulte the CYPRESS_DEV env var to "1"
          task :env do
            ENV["CYPRESS_DEV"] = "1"
          end
        end
      end

      def yarn_cmd
        cmd  = "yarn"
        cmd += " --cwd #{@ui_engine_root}" unless defined?(ENGINE_ROOT)

        cmd
      end

      def cypress_env_file
        File.expand_path("cypress.env.json", @ui_engine_root)
      end

      def app_prefix
        defined?(ENGINE_ROOT) ? "app:" : ""
      end
    end
  end
end
