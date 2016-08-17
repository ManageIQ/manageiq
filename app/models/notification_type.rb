class NotificationType < ApplicationRecord
  validates :message, :presence => true
  validates :level, :inclusion => { :in => %w(success error warning info) }
  validates :audience, :inclusion => { :in => %w(user tenant global) }
end
