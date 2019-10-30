import eppy
import json
import shutil

import subprocess
import os
import sys
from eppy.modeleditor import IDF

def modify_template_idf(plant_configuration_json_file,
                        base_template_idf='base_plant.idf',
                        modified_template_idf='in.idf',
                        idd_file="C:/EnergyPlusV9-1-0/Energy+.idd"):

    IDF.setiddname(idd_file)
    idf = IDF(base_template_idf)
    with open(plant_configuration_json_file) as json_file:
        data = json.load(json_file)



idd_file="C:/EnergyPlusV9-1-0/Energy+.idd"
base_template_idf = "base_CentralHeatPumpSystem.idf"

IDF.setiddname(idd_file)
idf = IDF(base_template_idf)

idf_central_heat_pump_system = idf.idfobjects['CentralHeatPumpSystem'][0]


# print(idf_central_heat_pump_system)
# print(idf.idfobjects['ChillerHeaterPerformance:Electric:EIR'])

base_chiller_heater_eir = idf.idfobjects['ChillerHeaterPerformance:Electric:EIR'][0]

NOMINAL_COP = 3.2
DICT_CHILLER_HEATER = 5

# for i in range(1, DICT_CHILLER_HEATER+1):
#     if i == 1:
#         temp_chiller_boiler_eir = base_chiller_heater_eir
#     else:
#         temp_chiller_boiler_eir = idf.copyidfobject(base_chiller_heater_eir)
#     temp_chiller_boiler_eir.Name = f"Chiller Heater Performance Electric EIR {i}"
#     temp_chiller_boiler_eir.Reference_Cooling_Mode_COP = NOMINAL_COP

base_chiller_heater_eir.Reference_Cooling_Mode_COP = NOMINAL_COP
idf_central_heat_pump_system.Number_of_Chiller_Heater_Modules_1 = DICT_CHILLER_HEATER


print(idf_central_heat_pump_system)
print(idf.idfobjects['ChillerHeaterPerformance:Electric:EIR'])