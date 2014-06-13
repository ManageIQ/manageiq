class VmdbDatabaseSetting < ActsAsArModel
  set_columns_hash(
    :name              => :string,
    :description       => :string,
    :value             => :string,
    :minimum_value     => :integer,
    :maximum_value     => :integer,
    :unit              => :string,
    :vmdb_database_id  => :integer
  )

  virtual_belongs_to :vmdb_database

  def initialize(values = {})
    values[:vmdb_database] ||= self.class.vmdb_database
    super(values)
  end

  #
  # Attributes and Reflections
  #

  def model_name
    self.name.singularize.camelize
  end

  def model
    return @model if instance_variable_defined?(:@model)
    @model = self.model_name.constantize rescue nil
  end

  def arel_table
    Arel::Table.new(self.name)
  end

  def vmdb_database
    VmdbDatabase.find_by_id(self.vmdb_database_id)
  end

  def vmdb_database=(db)
    self.vmdb_database_id = db.id
  end

  #
  # Finders
  #

  def self.find(*args)
    settings = self.vmdb_database_settings

    options = args.extract_options!

    case args.first
    when :first then settings.empty? ? nil : self.new(settings.first)
    when :last  then settings.empty? ? nil : self.new(settings.last)
    when :all   then settings.collect { |hash| self.new(hash) }
    end
  end

  protected

  def self.vmdb_database
    @vmdb_database ||= VmdbDatabase.my_database
  end

  def self.vmdb_database_settings
    settings = ActiveRecord::Base.connection.configuration_settings
    settings.collect { |hash| filtered_hash(hash) }
  end

  def self.dictionary_postgresql
    @dictionary_postgresql ||= {
      :name          => 'name',
      :description   => 'description',
      :value         => 'setting',
      :minimum_value => 'min_val',
      :maximum_value => 'max_val',
      :unit          => 'unit'
    }
  end

  def self.dictionary
    case ActiveRecord::Base.connection.adapter_name
    when 'PostgreSQL'; dictionary_postgresql
    else
      {}
    end
  end

  def self.filtered_hash(hash)
    filtered_hash = {}
    dictionary.each { |key, pg_key| filtered_hash[key] = hash[pg_key] }
    filtered_hash
  end

end
