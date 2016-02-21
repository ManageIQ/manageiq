class OpenscapRuleResult < ApplicationRecord
  include ReportableMixin

  belongs_to :openscap_result
end
