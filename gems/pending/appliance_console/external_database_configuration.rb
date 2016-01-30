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
      ask_questions if host.nil?
      super
    end

    def ask_questions
      create_new_region_questions if create_or_join_region_question == :create
      clear_screen
      say("Database Configuration\n")
      ask_for_database_credentials
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
