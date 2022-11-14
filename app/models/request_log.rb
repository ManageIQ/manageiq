class RequestLog < ApplicationRecord
  belongs_to :resource, polymorphic: true
end
