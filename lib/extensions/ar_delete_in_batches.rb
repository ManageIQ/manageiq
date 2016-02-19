module ArDeleteInBatches
  extend ActiveSupport::Concern

  module ClassMethods
    def delete_in_batches(window = 100, limit = nil)
      ids = select(:id).limit(window)
      total = 0
      loop do
        # determine how many records we want to try and delete
        # if we are nearing our limit, reduce the count
        current_window = limit ? (limit - total) : window
        if current_window && (window > current_window)
          ids = ids.limit(current_window)
        end

        # use a subquery
        # do not fetch the ids
        cur_ids = ids

        count = unscoped.where(:id => cur_ids).delete_all
        break if count == 0
        total += count

        yield(count, total) if block_given?
        break if count < window || (limit && total >= limit)
      end
      total
    end
  end
end

ActiveRecord::Base.send(:include, ArDeleteInBatches)
