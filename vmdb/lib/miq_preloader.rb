module MiqPreloader
  def self.preload(records, associations, options = {})
    ActiveRecord::Associations::Preloader.new(records, associations, options).run
  end
end
