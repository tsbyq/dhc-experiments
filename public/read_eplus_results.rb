require "CSV"

# CSV.read("favorite_foods.csv")

run_dir = Dir.getwd + '/runs/run_1567555917344'
out_csv_dir = run_dir + "/sys_1/eplusout.csv"


# table = CSV.parse(out_csv_dir, headers: true)
table = CSV.read(out_csv_dir, headers: true)

# puts table

puts table[0]['Electricity:Facility [J](Annual)']
puts table[0]['Gas:Facility [J](Annual)']
