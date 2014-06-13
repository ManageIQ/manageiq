module ApplianceConsole
  class ExternalDatabaseConfiguration < DatabaseConfiguration
    def initialize(hash = {})
      set_defaults
      super
    end

    def set_defaults
      self.username = "root"
      self.database = "vmdb_production"
    end

    def activate
      ask_questions if self.host.nil?
      super
    end

    def ask_questions
      create_new_region_questions if create_or_join_region_question == :create
      clear_screen
      ask_for_database_credentials
    end

    def ask_for_database_credentials
      say("Database Configuration\n")

      self.host     = ask_for_ip_or_hostname("database hostname or IP address", host)
      self.database = just_ask("name of the database on #{@host}", database)
      self.username = just_ask("username", username) unless local?
      self.password = ask_for_password_or_none("password ('none' for no value)", password) unless local?
    end

    def create_or_join_region_question
      clear_screen
      ask_with_menu("Database Region",
                    'Create new region'    => :create,
                    'Join existing region' => :join
      )
    end
  end
end
