class ShareReceiver < ApplicationRecord
  belongs_to :share
  belongs_to :tenant
end
