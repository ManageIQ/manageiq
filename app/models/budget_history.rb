class BudgetHistory < ApplicationRecord
  belongs_to :budget

  def cost
    attributes.select {|x| x.include?('cost')}.map{ |x| x[1] }.compact.sum
  end
end
