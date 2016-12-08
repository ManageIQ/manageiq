class NotificationType < ApplicationRecord
  AUDIENCE_USER = 'user'.freeze
  AUDIENCE_GROUP = 'group'.freeze
  AUDIENCE_TENANT = 'tenant'.freeze
  AUDIENCE_GLOBAL = 'global'.freeze
  AUDIENCE_SUPERADMIN = 'superadmin'.freeze
  has_many :notifications
  validates :message, :presence => true
  validates :level, :inclusion => { :in => %w(success error warning info) }
  validates :audience, :inclusion => {
    :in => [AUDIENCE_USER, AUDIENCE_GROUP, AUDIENCE_TENANT, AUDIENCE_GLOBAL, AUDIENCE_SUPERADMIN]
  }

  def subscriber_ids(subject, initiator)
    case audience
    when AUDIENCE_GLOBAL
      User.pluck(:id)
    when AUDIENCE_USER
      [initiator.id]
    when AUDIENCE_GROUP
      subject.try(:requester).try(:current_group).try(:user_ids)
    when AUDIENCE_TENANT
      subject.tenant.user_ids
    when AUDIENCE_SUPERADMIN
      User.superadmins.pluck(:id)
    end
  end

  def self.names
    @names ||= Set.new(pluck(:name))
  end

  def self.seed
    seed_data.each do |t|
      rec = find_by_name(t[:name])
      t[:expires_in] = t[:expires_in].to_i_with_method
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
