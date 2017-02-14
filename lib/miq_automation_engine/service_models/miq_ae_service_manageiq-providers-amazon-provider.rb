module MiqAeMethodService
  class MiqAeServiceManageIQ_Providers_Amazon_Provider < MiqAeServiceProvider
    expose :s3_storage_manager, :association => true
  end
end
