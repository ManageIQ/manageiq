class NotificationType < ApplicationRecord
  has_many :notifications
  validates :message, :presence => true
  validates :level, :inclusion => { :in => %w(success error warning info) }
  validates :audience, :inclusion => { :in => %w(user tenant global) }
end
