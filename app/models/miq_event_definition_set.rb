class MiqEventDefinitionSet < ApplicationRecord
  acts_as_miq_set

  def self.seed
    CSV.foreach(fixture_path, :headers => true, :skip_lines => /^#/) do |csv_row|
      set = csv_row.to_hash

      rec = find_by(:name => set['name'])
      if rec.nil?
        _log.info("Creating [#{set['name']}]")
        create!(set)
      else
        rec.attributes = set
        if rec.changed?
          _log.info("Updating [#{set['name']}]")
          rec.save!
        end
      end
    end
  end

  def self.fixture_path
    FIXTURE_DIR.join("#{to_s.pluralize.underscore}.csv")
  end
end
