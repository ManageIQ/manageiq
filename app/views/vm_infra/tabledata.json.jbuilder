table = @view.sub_table ? @view.sub_table : @view.table

json.draw params[:draw]
json.recordsTotal @pages[:items]
json.recordsFiltered @pages[:items]
json.pageLength table.data.length
json.data table.data.map { |row| row.data }
