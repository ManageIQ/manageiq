class MiqSearch < ActiveRecord::Base
  serialize :options
  serialize :filter

  validates_uniqueness_of :name, :scope => "db"

  has_many  :miq_schedules

  before_destroy :check_schedules_empty_on_destroy

  def check_schedules_empty_on_destroy
    raise "Search is referenced in a schedule and cannot be deleted" unless self.miq_schedules.empty?
  end

  def search_type
    read_attribute(:search_type) || "default"
  end

  def search(targets = [], opts = {})
    self.options ||= {}
    Rbac.search(self.options.merge(:targets => targets, :class => self.db, :filter => self.filter).merge(opts))
  end

  def self.get_expressions_by_model(db)
    get_expressions(:db => db.to_s)
  end

  def self.get_expressions(options)
    self.all(:conditions => options).each_with_object({}) do |r, hash|
      hash[r.description] = r.id unless r.filter.nil?
    end
  end

  FIXTURE_DIR = File.join(Rails.root, "db/fixtures")
  def self.seed
    MiqRegion.my_region.lock do
      fixture_file = File.join(FIXTURE_DIR, "miq_searches.yml")
      slist        = YAML.load_file(fixture_file) if File.exists?(fixture_file)
      slist      ||= []

      slist.each do |search|
        attrs = search['attributes']
        name  = attrs['name']
        db    = attrs['db']

        rec = self.find_by_name_and_db(name, db)
        if rec.nil?
          $log.info("MIQ(MiqSearch.seed) Creating [#{name}]")
          rec = self.create(attrs)
        else
          # Avoid undoing user changes made to enable/disable default searches which is held in the search_key column
          attrs.delete('search_key')
          rec.attributes = attrs
          rec.save
        end
      end
    end
  end
end
