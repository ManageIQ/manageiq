module ApplicationController::Timelines
  # We need the Open struct until we get rid of :"pol_filter#{i}" and :"pol_fltr#{i}"
  class Options < OpenStruct
    def tl_colors
      ['#CD051C', '#005C25', '#035CB1', '#FF3106', '#FF00FF', '#000000']
    end
  end
end
