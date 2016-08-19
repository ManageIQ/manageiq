require 'active_support/all'
require 'util/miq-password'
require 'fileutils'

module PostgresHaAdmin
  class DatabaseYml
    attr_reader :db_yml_file, :environment

    def initialize(db_yml_file, environment)
      @db_yml_file = db_yml_file
      @environment = environment
    end

    def pg_params_from_database_yml
      rails_params_to_pg(YAML.load_file(db_yml_file)[environment])
    end

    def update_database_yml(params)
      db_yml = YAML.load_file(db_yml_file)
      db_yml[environment].merge!(pg_parameters_to_rails(params))
      remove_empty(db_yml[environment])

      new_name = "#{db_yml_file}_#{Time.current.strftime("%d-%B-%Y_%H.%M.%S")}"
      FileUtils.copy(db_yml_file, new_name)
      begin
        File.write(db_yml_file, db_yml.to_yaml)
      rescue StandardError
        FileUtils.mv(new_name, db_yml_file)
        raise
      end
      new_name
    end

    private

    def rails_params_to_pg(params)
      pg_params = {}
      pg_params[:dbname] = params['database']
      pg_params[:user] = params['username']
      pg_params[:port] = params['port']
      pg_params[:host] = params['host']
      pg_params[:password] = MiqPassword.try_decrypt(params['password'])
      remove_empty(pg_params)
    end

    def pg_parameters_to_rails(pg_params)
      params = {}
      params['username'] = pg_params[:user]
      params['database'] = pg_params[:dbname]
      params['port'] = pg_params[:port]
      params['host'] = pg_params[:host]
      remove_empty(params)
    end

    def remove_empty(hash)
      hash.delete_if { |_k, v| v.nil? || v.to_s.strip.empty? }
    end
  end
end
