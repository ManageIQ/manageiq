class MiqShortcut < ActiveRecord::Base
  has_many :miq_widget_shortcuts, :dependent => :destroy
  has_many :miq_widgets, :through => :miq_widget_shortcuts

  def self.seed
    log_header = "MIQ(MiqShortcut.seed)"
    MiqRegion.my_region.lock do
      names = []
      seed_data.each_with_index do |s, index|
        names << s[:name]
        s[:sequence] = index
        rec = self.find_by_name(s[:name])
        if rec.nil?
          $log.info("#{log_header} Creating #{s.inspect}")
          rec = self.create(s)
        else
          rec.attributes = s
          if rec.changed?
            $log.info("#{log_header} Updating #{s.inspect}")
            rec.save
          end
        end
      end

      self.all.each do |rec|
        next if names.include?(rec.name)
        $log.info("#{log_header} Deleting #{rec.inspect}")
        rec.destroy
      end
    end
  end

  def self.fixture_file_name
    @fixture_file_name ||= File.join(Rails.root, "db/fixtures", "miq_shortcuts.yml")
  end

  def self.seed_data
    File.exists?(fixture_file_name) ? YAML.load_file(fixture_file_name) : []
  end

  def self.start_pages
    self.where(:startup => true).sort_by { |s| s.sequence.to_i }.collect { |s| [s.url, s.description, s.rbac_feature_name] }
  end
end
