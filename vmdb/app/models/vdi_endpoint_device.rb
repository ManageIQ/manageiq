class VdiEndpointDevice < ActiveRecord::Base
  has_many   :vdi_sessions
  has_many   :ems_events

  include ReportableMixin
  include ArCountMixin
end
