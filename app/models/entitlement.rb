class Entitlement < ApplicationRecord
  belongs_to :miq_group
  belongs_to :miq_user_role
end
