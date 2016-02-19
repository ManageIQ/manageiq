puts "Deleting ems_metadata Relationships..."
Relationship.where(:relationship => "ems_metadata").delete_all
puts "Deleting ems_metadata Relationships...Complete"
