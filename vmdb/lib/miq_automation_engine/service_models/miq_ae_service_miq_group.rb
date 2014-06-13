module MiqAeMethodService
  class MiqAeServiceMiqGroup < MiqAeServiceModelBase
    expose :users, :association => true
    expose :vms,   :association => true

    def custom_keys
      object_send(:miq_custom_keys)
    end

    def custom_get(key)
      object_send(:miq_custom_get, key)
    end

    def custom_set(key, value)
      ar_method do
        @object.miq_custom_set(key, value)
        @object.save
      end
      value
    end
  end
end
