name1 = 'base.idf'
name2 = 'plant_loop.idf'

base_content = open(name1, "r").read()
plant_loop_content = open(name2, "r").read()


f_final_content = open('final.idf', 'w')
f_final_content.write(base_content)
f_final_content.write(plant_loop_content)
