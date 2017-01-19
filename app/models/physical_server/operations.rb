module PhysicalServer::Operations
  extend ActiveSupport::Concern

  include_concern 'Power'
  include_concern 'Led'

end
