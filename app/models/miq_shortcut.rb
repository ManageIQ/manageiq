class MiqShortcut < ApplicationRecord
  has_many :miq_widget_shortcuts, :dependent => :destroy
  has_many :miq_widgets, :through => :miq_widget_shortcuts

  def self.seed
    db_data = all.index_by(&:name)
    seed_records = seed_data

    seed_records_by_name = seed_records.group_by { |x| x[:name] }
    if seed_records.size != seed_records_by_name.size
      names = seed_records_by_name.select { |_n, v| v.size > 1 }.map(&:first)
      _log.warn("Duplicate seeds for names: #{names.join(",")}")
    end

    seed_records.each_with_index do |s, index|
      s[:sequence] = index
      rec = db_data[s[:name]]
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

    db_data.each do |name, rec|
      next if seed_records_by_name[name]
      _log.info("Deleting #{rec.inspect}")
      rec.destroy
    end
  end

  def self.fixture_file_names
    shortcuts_dir = FIXTURE_DIR.join("miq_shortcuts")
    main_shortcuts = FIXTURE_DIR.join("miq_shortcuts.yml")
    [main_shortcuts] + (shortcuts_dir.directory? ? shortcuts_dir.children : [])
  end

  def self.seed_data
    fixture_file_names.flat_map { |file| YAML.load_file(file) }
  end

  def self.start_pages
    where(:startup => true).sort_by { |s| s.sequence.to_i }.collect { |s| [s.url, s.description, s.rbac_feature_name] }
  end

  def self.display_name(number = 1)
    n_('Shortcut', 'Shortcuts', number)
  end
end
