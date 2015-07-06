puts "Deleting ems_metadata Relationships..."
Relationship.delete_all(:relationship => "ems_metadata")
puts "Deleting ems_metadata Relationships...Complete"
