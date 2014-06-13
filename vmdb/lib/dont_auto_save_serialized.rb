# In ActiveRecord, serialized columns will be saved whether they changed or not
# Adding this module makes serialized act more like a typical column.
#
# example:
#
# class FancyClass < ActiveRecord::Base
#   include DontAutoSaveSerialized
#   serialized :lots_o_data
# end
#
# fc = FancyClass.first
# fc.lots_o_data = {:a => 5}
# # this works with or without the module included
#
# fc.lots_o_data_will_change!
# fc.logs_o_data[:b] = 5
# # if the module is included, inline changes require will_change!
# # without the module, will_change not required here (it ALWAYS saves the column)
#
module DontAutoSaveSerialized
  # Of note, rails has been patched to be more like rails 4.x
  #
  # it now reads:
  #
  # https://github.com/ManageIQ/rails/blob/vendored_3_2_13/activerecord/lib/active_record/attribute_methods/dirty.rb#L70-82
  # def update(*)
  #   super(keys_for_partial_write)
  # end

  # This is overriding the previous behavior which said a serialized column
  # should always be updated
  #
  # before:
  # changed | (attributes.keys & self.class.serialized_attributes.keys)
  def keys_for_partial_write
    changed
  end

  # This is overriding the previous behavior which said save timestamp
  # if there are any serialized columns.
  #
  # before included:
  #   (attributes.keys & self.class.serialized_attributes.keys).present?
  #
  # NOTE: for 4.x, partial_updates? was renamed to partial_writes
  def should_record_timestamps?
    self.record_timestamps && (!partial_updates? || changed?)
  end
end
