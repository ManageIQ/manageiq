# If code uses the old constant name:
#   * Rails will autoload it and start here.
#   * We assign the old toplevel constant to the new constant.
#   * We can't include rails deprecate_constant globally, so we use ruby's.
Charting = ManageIQ::Reporting::Charting
Object.deprecate_constant :Charting
