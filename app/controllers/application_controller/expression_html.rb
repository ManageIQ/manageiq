module ApplicationController::ExpressionHtml
  # Build a string from an array of expression symbols by recursively traversing the MiqExpression object
  #   and inserting sequential tokens for each expression part
  def exp_build_string(exp)
    exp_string = ""
    exp_tooltip = "" # string for tooltip without fonts tags
    if exp["and"]
      fcolor = calculate_font_color(exp["result"])
      exp_string << "<font color=#{fcolor}><b>(</b></font>"
      exp_tooltip << "("
      exp["and"].each do |e|
        fcolor = calculate_font_color(e["result"])
        exp_str, exp_tip = exp_build_string(e)
        if exp["result"] && !e["result"]
          exp_string << "<font color=#{fcolor}><i>" << exp_str << "</i></font>"
        else
          exp_string << "<font color=#{fcolor}>" << exp_str << "</font>"
        end
        exp_tooltip << exp_tip
        fcolor = calculate_font_color(exp["result"])
        exp_string << "<font color=#{fcolor}> <b>AND</b> </font>" unless e == exp["and"].last
        exp_tooltip << " AND " unless e == exp["and"].last
      end
      exp_string << "<font color=#{fcolor}><b>)</b></font>"
      exp_tooltip << ")"
    elsif exp["or"]
      fcolor = calculate_font_color(exp["result"])
      exp_string << "<font color=#{fcolor}><b>(</b></font>"
      exp["or"].each do |e|
        fcolor = calculate_font_color(e["result"])
        exp_str, exp_tip = exp_build_string(e)
        if exp["result"] && !e["result"]
          exp_string << "<font color=#{fcolor}><i>" << exp_str << "</i></font>"
        else
          exp_string << "<font color=#{fcolor}>" << exp_str << "</font>"
        end
        exp_tooltip << exp_tip
        fcolor = calculate_font_color(exp["result"])
        exp_string << "<font color=#{fcolor}> <b>OR</b> </font>" unless e == exp["or"].last
        exp_tooltip << " OR " unless e == exp["or"].last
      end
      exp_string << "<font color=#{fcolor}><b>)</b></font>"
      exp_tooltip << ")"
    elsif exp["not"]
      fcolor = calculate_font_color(exp["result"])
      exp_string << "<font color=#{fcolor}> <b>NOT</b> </font>"
      exp_tooltip << " NOT "
      # No parens if and/or under me
      exp_string << "<font color=#{fcolor}><b>(</b></font>" unless %w(and or).include?(exp["not"].keys.first)
      exp_tooltip << "(" unless %w(and or).include?(exp["not"].keys.first) # No parens if and/or under me
      exp_str, exp_tip = exp_build_string(exp["not"])
      if exp["result"] && !exp["not"]["result"]
        exp_string << "<font color=#{fcolor}><i>" << exp_str << "</i></font>"
      else
        exp_string << "<font color=#{fcolor}>" << exp_str << "</font>"
      end

      exp_tooltip << exp_tip
      # No parens if and/or under me
      exp_string << "<font color=#{fcolor}><b>)</b></font>" unless %w(and or).include?(exp["not"].keys.first)
      exp_tooltip << ")" unless %w(and or).include?(exp["not"].keys.first) # No parens if and/or under me
    else
      fcolor = calculate_font_color(exp["result"])
      temp_exp = copy_hash(exp)
      temp_exp.delete("result")
      exp_string << "<font color=#{fcolor}>" << MiqExpression.to_human(temp_exp) << "</font>"
      exp_tooltip << MiqExpression.to_human(temp_exp)
    end
    return exp_string, exp_tooltip
  end

  def calculate_font_color(result)
    fcolor = "black"
    if result == true
      fcolor = "green"
    elsif result == false
      fcolor = "red"
    end
    fcolor
  end
end
