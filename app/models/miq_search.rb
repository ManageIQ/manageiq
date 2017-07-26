class MiqSearch < ApplicationRecord
  serialize :options
  serialize :filter

  validates_uniqueness_of :name, :scope => "db"

  has_many  :miq_schedules

  before_destroy :check_schedules_empty_on_destroy

  def check_schedules_empty_on_destroy
    raise _("Search is referenced in a schedule and cannot be deleted") unless miq_schedules.empty?
  end

  def search_type
    read_attribute(:search_type) || "default"
  end

  def filtered(targets, opts = {})
    self.options ||= {}
    Rbac.filtered(targets, options.merge(:class => db, :filter => filter).merge(opts))
  end

  def quick_search?
    MiqExpression.quick_search?(filter)
  end

  def results(opts = {})
    filtered(db, opts)
  end

  def self.filtered(filter_id, klass, targets, opts = {})
    if filter_id.nil? || filter_id.zero?
      Rbac.filtered(targets, opts.merge(:class => klass))
    else
      find(filter_id).filtered(targets, opts)
    end
  end

  def self.visible_to_all
    where("search_type=? or (search_type=? and (search_key is null or search_key<>?))", "global", "default", "_hidden_")
  end

  def self.visible_to_current_user
    where(:search_type => 'user', :search_key => User.current_user.userid)
  end

  def self.filters_by_type(type)
    case type
    when "global" # Global filters
      visible_to_all
    when "my"     # My filters
      visible_to_current_user
    else
      raise "Error: #{type} is not a proper filter type!"
    end
  end

  def self.get_expressions_by_model(db)
    get_expressions(:db => db.to_s)
  end

  def self.get_expressions(options)
    where(options).each_with_object({}) do |r, hash|
      hash[r.description] = r.id unless r.filter.nil?
    end
  end

  def self.descriptions
    Hash[*all.select(:id, :description).flat_map {|x| [x.id.to_s, x.description] }]
  end

  FIXTURE_DIR = File.join(Rails.root, "db/fixtures")
  def self.seed
    fixture_file = File.join(FIXTURE_DIR, "miq_searches.yml")
    slist        = YAML.load_file(fixture_file) if File.exist?(fixture_file)
    slist ||= []

    slist.each do |search|
      attrs = search['attributes']
      name  = attrs['name']
      db    = attrs['db']

      rec = find_by(:name => name, :db => db)
      if rec.nil?
        _log.info("Creating [#{name}]")
        create!(attrs)
      else
        # Avoid undoing user changes made to enable/disable default searches which is held in the search_key column
        attrs.delete('search_key')
        rec.attributes = attrs
        rec.save!
      end
    end
  end
end
