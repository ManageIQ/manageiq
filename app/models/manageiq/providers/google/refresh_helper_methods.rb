module ManageIQ::Providers::Google::RefreshHelperMethods
  extend ActiveSupport::Concern

  def process_collection(collection, key)
    @data[key]       ||= []
    @data_index[key] ||= {}

    collection.each do |item|
      uid, new_result = yield(item)
      next if uid.nil?

      @data[key] << new_result
      @data_index.store_path(key, uid, new_result)
    end
  end

  def parse_uid_from_url(url)
    # A lot of attributes in gce are full URLs with the
    # uid being the last component.  This helper method
    # returns the last component of the url
    uid = url.split('/')[-1]
    uid
  end

  module ClassMethods
    def ems_inv_to_hashes(ems, options = nil)
      new(ems, options).ems_inv_to_hashes
    end
  end
end
