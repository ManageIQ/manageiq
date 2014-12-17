module MiqPreloader
  def self.preload(records, associations, options = {})
    preloader = ActiveRecord::Associations::Preloader.new
    preloader.preload(records, associations)
  end
end
