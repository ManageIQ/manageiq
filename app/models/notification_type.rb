class NotificationType < ApplicationRecord
  AUDIENCE_USER = 'user'.freeze
  AUDIENCE_TENANT = 'tenant'.freeze
  AUDIENCE_GLOBAL = 'global'.freeze
  has_many :notifications
  validates :message, :presence => true
  validates :level, :inclusion => { :in => %w(success error warning info) }
  validates :audience, :inclusion => { :in => [AUDIENCE_USER, AUDIENCE_TENANT, AUDIENCE_GLOBAL] }

  def subscriber_ids(subject, initiator)
    case audience
    when AUDIENCE_GLOBAL
      User.pluck(:id)
    when AUDIENCE_USER
      [initiator.id]
    when AUDIENCE_TENANT
      subject.tenant.user_ids
    end
  end

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
