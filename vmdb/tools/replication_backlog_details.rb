region_number = MiqRegion.my_region_number

require 'pp'
RrPendingChange.for_region_number(region_number) do
  pp RrPendingChange.backlog_details
end
