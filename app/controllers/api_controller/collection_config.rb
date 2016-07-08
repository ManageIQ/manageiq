class ApiController
  class CollectionConfig < Config::Options
    def custom_actions?(collection_name)
      cspec = self[collection_name.to_sym]
      cspec && cspec[:options].include?(:custom_actions)
    end
  end
end
