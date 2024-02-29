class MiqDatabase < ApplicationRecord
  include ManageIQ::Password::PasswordMixin
  encrypt_column  :csrf_secret_token
  encrypt_column  :session_secret_token

  validates_presence_of :session_secret_token, :csrf_secret_token

  def self.seed
    db = first || new
    db.session_secret_token ||= SecureRandom.hex(64)
    db.csrf_secret_token ||= SecureRandom.hex(64)
    if db.changed?
      _log.info("#{db.new_record? ? "Creating" : "Updating"} MiqDatabase record")
      db.save!
    end
    db
  end

  def name
    ActiveRecord::Base.connection.current_database
  end

  def size
    ActiveRecord::Base.connection.database_size(name)
  end

  def self.adapter
    @adapter ||= ActiveRecord::Base.connection.instance_variable_get(:@config)[:adapter]
  end

  def self.display_name(number = 1)
    n_('Database', 'Databases', number)
  end
end
