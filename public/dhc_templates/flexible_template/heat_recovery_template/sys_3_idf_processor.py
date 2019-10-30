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
base_template_idf = "sys_3_template.idf"

IDF.setiddname(idd_file)
idf = IDF(base_template_idf)

NOMINAL_COP = 6.5
DICT_CHILLER_HEATER = 1

idf.idfobjects['ChillerHeaterPerformance:Electric:EIR'][0].Reference_Cooling_Mode_COP = NOMINAL_COP
idf.idfobjects['CentralHeatPumpSystem'][0].Number_of_Chiller_Heater_Modules_1 = DICT_CHILLER_HEATER


idf.save("C:/Users/hlee9/Documents/GitHub/dhc-experiments/public/dhc_templates/temp/heat_recovery/sys_3_mutated.idf")