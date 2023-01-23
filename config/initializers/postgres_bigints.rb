# Rails has a protection to not lookup values by a large number.
# A lookup/comparison with a large number (bigger than bigint)
# needs to cast the db column to a double/numeric.
# and that casting skips the index and forces a table scan
#
# https://discuss.rubyonrails.org/t/cve-2022-44566-possible-denial-of-service-vulnerability-in-activerecords-postgresql-adapter/82119
#
ActiveRecord::Base.raise_int_wider_than_64bit = false
