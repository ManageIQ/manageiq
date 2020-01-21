class MiqEventDefinitionSet < ApplicationRecord
  acts_as_miq_set

  def self.seed
    existing = all.group_by(&:name)
    CSV.foreach(fixture_path, :headers => true, :skip_lines => /^#/) do |csv_row|
      set = csv_row.to_hash

      rec = existing[set['name']].try(:first)
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

  def self.display_name(number = 1)
    n_('Event Definition Set', 'Event Definition Sets', number)
  end
end
