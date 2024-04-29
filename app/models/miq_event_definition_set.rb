class MiqEventDefinitionSet < ApplicationRecord
  acts_as_miq_set

  def self.set_definitions_from_path(path)
    YAML.load_file(path)
  end

  def self.seed
    existing = all.group_by(&:name)
    set_definitions_from_path(fixture_path).each do |set|
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
    FIXTURE_DIR.join("#{to_s.pluralize.underscore}.yml")
  end

  def self.display_name(number = 1)
    n_('Event Definition Set', 'Event Definition Sets', number)
  end

  alias_method :events, :miq_event_definitions
end
