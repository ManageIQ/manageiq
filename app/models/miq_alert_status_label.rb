#
# This class represents a name/value pair used to store alert labels. Currently this isn't persisted to a table, but
# fetched using the `alert_labels` method of the providers that support the alert labels feature.
#
class MiqAlertStatusLabel
  attr_accessor :name
  attr_accessor :value
end
