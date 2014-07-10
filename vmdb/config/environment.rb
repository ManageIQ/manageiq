# Load the rails application
require File.expand_path('../application', __FILE__)

# Initialize the rails application
Vmdb::Application.initialize!

# Eager load Subclasses
BASE_CLASSES = ["FileDepot"]

BASE_CLASSES.each { |klass| VMDB::Util.eager_load_subclasses(klass) }
