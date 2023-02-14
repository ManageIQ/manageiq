class RequestLog < ApplicationRecord
  validates :severity, :inclusion => {:in => Logger::Severity.constants.map(&:to_s)}

  belongs_to :resource, :class_name => "MiqRequest"
end
