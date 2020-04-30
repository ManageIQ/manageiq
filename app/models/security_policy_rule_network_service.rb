class SecurityPolicyRuleNetworkService < ApplicationRecord
  belongs_to :security_policy_rule
  belongs_to :network_service
end
