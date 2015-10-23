class MiqEventDefinitionSet < ActiveRecord::Base
  acts_as_miq_set

  default_scope { where conditions_for_my_region_default_scope }

  def self.seed
    CSV.foreach(fixture_path, :headers => true, :skip_lines => /^#/) do |csv_row|
      set = csv_row.to_hash

      rec = find_by_name(set['name'])
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
    Rails.root.join("db/fixtures/#{to_s.pluralize.underscore}.csv")
  end
end
