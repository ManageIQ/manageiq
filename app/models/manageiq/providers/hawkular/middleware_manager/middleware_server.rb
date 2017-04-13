module ManageIQ::Providers
  class Hawkular::MiddlewareManager::MiddlewareServer < MiddlewareServer
    def immutable?
      properties['Immutable'] == 'true'
    end
  end
end
