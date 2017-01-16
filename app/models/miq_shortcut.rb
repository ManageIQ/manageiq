class MiqShortcut < ApplicationRecord
  has_many :miq_widget_shortcuts, :dependent => :destroy
  has_many :miq_widgets, :through => :miq_widget_shortcuts

  def self.seed
    names = []
    seed_data.each_with_index do |s, index|
      names << s[:name]
      s[:sequence] = index
      rec = find_by(:name => s[:name])
      if rec.nil?
        _log.info("Creating #{s.inspect}")
        rec = create!(s)
      else
        rec.attributes = s
        if rec.changed?
          _log.info("Updating #{s.inspect}")
          rec.save!
        end
      end
    end

    all.each do |rec|
      next if names.include?(rec.name)
      _log.info("Deleting #{rec.inspect}")
      rec.destroy
    end
  end

  def self.fixture_file_names
    shortcuts_dir = FIXTURE_DIR.join("miq_shortcuts")
    main_shortcuts = FIXTURE_DIR.join("miq_shortcuts.yml")
    [main_shortcuts, (shortcuts_dir.directory? ? shortcuts_dir : nil)]
  end

  def self.seed_data
    main_file, dir = fixture_file_names
    fixtures_from_dir = []
    if dir
      dir.children.each do |file|
        fixture_file = YAML.load_file(file)
        fixtures_from_dir += fixture_file
      end
    end
    YAML.load_file(main_file) + fixtures_from_dir
  end

  def self.start_pages
    where(:startup => true).sort_by { |s| s.sequence.to_i }.collect { |s| [s.url, s.description, s.rbac_feature_name] }
  end
end
