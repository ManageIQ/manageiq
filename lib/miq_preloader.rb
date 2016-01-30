module MiqPreloader
  def self.preload(records, associations, _options = {})
    preloader = ActiveRecord::Associations::Preloader.new
    preloader.preload(records, associations)
  end
end
