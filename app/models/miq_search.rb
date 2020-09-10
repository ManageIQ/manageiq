class MiqSearch < ApplicationRecord
  serialize :options
  serialize :filter
  include_concern 'ImportExport'
  include YAMLImportExportMixin

  validates :name, :uniqueness_when_changed => {:scope => "db"}

  # validate if the name of a new filter is unique in Global Filters
  validates :description, :uniqueness_when_changed => {:scope => "db", :conditions => -> { where.not(:search_type => 'user') },
                          :if => proc { |miq_search| miq_search.search_type == 'global' }}

  has_many  :miq_schedules

  before_destroy :check_schedules_empty_on_destroy

  def check_schedules_empty_on_destroy
    unless miq_schedules.empty?
      errors.add(:base, _("Search is referenced in a schedule and cannot be deleted"))
      throw :abort
    end
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
    searches = where("name like 'default%'").index_by { |ms| "#{ms.name}-#{ms.db}" }
    fixture_file = File.join(FIXTURE_DIR, "miq_searches.yml")
    slist        = YAML.load_file(fixture_file) if File.exist?(fixture_file)
    slist ||= []
    slist.group_by { |s| [s['attributes']['name'], s['attributes']['db']] }.each do |(name, db), dups|
      _log.warn("duplicate entry for db=#{db} name=#{name}") if dups.size > 1
    end
    slist.each do |search|
      attrs = search['attributes']
      name  = attrs['name']
      db    = attrs['db']

      rec = searches.delete("#{name}-#{db}")
      if rec.nil?
        _log.info("Creating [#{name}]")
        create!(attrs)
      else
        # Avoid undoing user changes made to enable/disable default searches which is held in the search_key column
        attrs.delete('search_key')

        # properly compare filter
        filter = attrs.delete('filter')
        rec.filter = filter if rec.filter.exp != filter.exp
        rec.attributes = attrs

        rec.save! if rec.changed?
      end
    end
    if searches.any?
      _log.warn("Deleting the following MiqSearch(es) as they no longer exist: #{searches.keys.sort.collect(&:inspect).join(", ")}")
      MiqSearch.destroy(searches.values.map(&:id))
    end
  end

  def self.display_name(number = 1)
    n_('Search', 'Searches', number)
  end
end
