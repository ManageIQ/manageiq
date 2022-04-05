module PhysicalServer::Operations
  extend ActiveSupport::Concern

  include_concern 'Power'
  include_concern 'Led'
  include_concern 'ConfigPattern'
  include_concern 'Lifecycle'
end
