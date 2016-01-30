class DriftState < ApplicationRecord
  include_concern 'Purging'

  belongs_to :resource, :polymorphic => true

  serialize :data

  def data_obj
    require 'miq-hash_struct'
    hashes_to_struct(data.deep_clone)
  end

  private

  def hashes_to_struct(obj)
    case obj
    when Hash
      obj.keys.each { |k| obj[k] = hashes_to_struct(obj[k]) }
      MiqHashStruct.new(obj)
    when Array
      obj.collect! { |i| hashes_to_struct(i) }
    else
      obj
    end
  end
end
