# Simple engine config for routes to access factories and such from the
# frontend via API calls (`cypress`, etc.)
#
# Inspired heavily from the following blog post:
#
#   https://blog.simplificator.com/2019/10/11/setting-up-cypress-with-rails/
#

require Rails.root.join("spec/support/factory_bot_helper")

module ManageIQ
  module Integration
    class Engine < ::Rails::Engine
      routes.draw do
        namespace :miq do
          namespace :db do
            delete "clean", :to => "/manageiq/integration/db#clean"
          end

          namespace :factory do
            post "create", :to => "/manageiq/integration/factory#create"
          end
        end
      end

    end

    # Database cleaner controller
    #
    class DbController < ActionController::Base
      # Class variable with a memoized instance of DatabaseCleaner
      #
      # Lazy loaded so it isn't instanciated on Engine load
      #
      def self.cleaner
        @cleaner ||= DatabaseCleaner.new
      end

      ##
      # Run Factory.create for a Factory of :name
      #
      # See ManageIQ::Integration::DatabaseCleaner for more info
      #
      # @path [DELETE] /miq/db/clean
      #
      def clean
        self.class.cleaner.clean

        head :ok
      end
    end

    # FactoryBot via HTTP controller
    #
    class FactoryController < ActionController::Base
      ##
      # Run Factory.create for a Factory of :name
      #
      # @path [POST] /miq/factory/create
      #
      # @parameter name(required) [string]  Name of the Factory
      # @parameter attributes     [hash]    Attributes of the Factory to override
      #
      def create
        create_opts = params.permit(:name, :attributes => {})
        factory     = FactoryBot.create(create_opts[:name], create_opts[:attributes])

        render :json => factory
      end
    end
  end
end
