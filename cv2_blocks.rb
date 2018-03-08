puts "Hello World!"


def latte_macchiato(a) 
	puts "milk foam"
	yield(a)
	puts "milk"
end


latte_macchiato(8) do |grams|
	puts "expresso #{grams} g"
end
