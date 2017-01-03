require_relative '../miq_ae_service/miq_ae_service_object_common'
module MiqAeMethodService
  class MiqAeServiceObject
    include MiqAeMethodService::MiqAeServiceObjectCommon
    include DRbUndumped

    def initialize(obj, svc)
      raise "object cannot be nil" if obj.nil?
      @object  = obj
      @service = svc
    end

    def children(name = nil)
      objs = @object.children(name)
      return nil if objs.nil?
      objs = @service.objects([objs].flatten)
      objs.length == 1 ? objs.first : objs
    end

    def to_s
      name
    end

    def inspect
      hex_id = (object_id << 1).to_s(16).rjust(14, '0')
      "#<#{self.class.name}:0x#{hex_id} name: #{name.inspect}>"
    end
  end
end
