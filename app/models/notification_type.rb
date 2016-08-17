class NotificationType < ApplicationRecord
  has_many :notifications
  validates :message, :presence => true
  validates :level, :inclusion => { :in => %w(success error warning info) }
  validates :audience, :inclusion => { :in => %w(user tenant global) }

  def self.seed
    seed_data.each do |t|
      rec = find_by_name(t[:name])
      t[:expires_in] = $1.to_i.send($2).to_i if t[:expires_in] =~ /^(\d+) (minutes?|hours?|days?)$/
      if rec.nil?
        create(t)
      else
        rec.update_attributes(t)
        rec.save!
      end
    end
  end

  def self.seed_data
    fixture_file = File.join(FIXTURE_DIR, 'notification_types.yml')
    File.exist?(fixture_file) ? YAML.load_file(fixture_file) : []
  end
end
