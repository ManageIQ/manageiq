class AuthenticationOrchestrationStack < ApplicationRecord
  belongs_to :authentication
  belongs_to :orchestration_stack
end
