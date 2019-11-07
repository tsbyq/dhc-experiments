import eppy
import json
import shutil
import time
import datetime

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

    def add_template_chiller(idf,
                             chiller_name,
                             chiller_type='ElectricCentrifugalChiller',
                             cop=3.5,
                             condenser_type='WaterCooled'):
        idf.newidfobject("HVACTemplate:Plant:Chiller")
        idf_new_template_chiller = idf.idfobjects['HVACTemplate:Plant:Chiller'][-1]
        idf_new_template_chiller.Name = chiller_name
        idf_new_template_chiller.Chiller_Type = chiller_type
        idf_new_template_chiller.Nominal_COP = cop
        idf_new_template_chiller.Condenser_Type = condenser_type
        idf_new_template_chiller.Priority = 1
        idf_new_template_chiller.Sizing_Factor = ''
        idf_new_template_chiller.Minimum_Part_Load_Ratio = ''
        idf_new_template_chiller.Maximum_Part_Load_Ratio = ''
        idf_new_template_chiller.Optimum_Part_Load_Ratio = ''
        idf_new_template_chiller.Minimum_Unloading_Ratio = ''
        idf_new_template_chiller.Leaving_Chilled_Water_Lower_Temperature_Limit = ''
        return idf

    def add_template_boiler(idf, boiler_name, efficiency=0.8, fuel_type="NaturalGas"):
        idf.newidfobject("HVACTemplate:Plant:Boiler")
        idf_new_template_boiler = idf.idfobjects['HVACTemplate:Plant:Boiler'][-1]
        idf_new_template_boiler.Name = boiler_name
        idf_new_template_boiler.Efficiency = efficiency
        idf_new_template_boiler.Fuel_Type = fuel_type
        return idf

    for count, chiller in enumerate(data['chillers']):
        idf = add_template_chiller(idf, f"Chiller No. {count+1}", chiller['type'], chiller['COP'], chiller['condenser'])

    for count, boiler in enumerate(data['boilers']):
        idf = add_template_boiler(idf, f"Boiler No. {count+1}", boiler['efficiency'], fuel_type=boiler['fuel'])

    print('---> Adding template chiller and boiler done.')
    idf.saveas(modified_template_idf)


def expand_template_idf(template_idf='in.idf',
                        expanded_template_idf='expanded.idf',
                        expand_objects_exe='C:/EnergyPlusV9-1-0/ExpandObjects.exe'):
    cmd = [expand_objects_exe]
    p = subprocess.Popen(cmd)
    p.wait()


def auto_update_LP_flow_rates(idf, peak_heating_w, peak_cooling_w):
    # This function calculates and updates the peak flow rates of the LoadProfile:Plant objects
    CP_WATER = 4186 # J/(kg*C)
    DELTA_T_H = 25 # C
    DELTA_T_C = 7 # C
    RHO_WATER = 1000 #kg/m3
    SAFE_FACTOR = 1.5

    v_peak_flow_heating = abs(peak_cooling_w)/(CP_WATER * DELTA_T_H * RHO_WATER) # peak flow rate (m3/s)
    v_peak_flow_cooling = abs(peak_heating_w)/(CP_WATER * DELTA_T_C * RHO_WATER) # peak flow rate (m3/s)
    v_lp = idf.idfobjects['LoadProfile:Plant']
    for lp in v_lp:
        if lp.Name == "District Heating Load Profile":
            lp.Peak_Flow_Rate = v_peak_flow_heating * SAFE_FACTOR
        elif lp.Name == "District Cooling Load Profile":
            lp.Peak_Flow_Rate = v_peak_flow_cooling * SAFE_FACTOR

    idf.idfobjects['LoadProfile:Plant'] = v_lp
    return idf

def prepare_LP_plantloop(expanded_plant_loop_idf='expanded.idf',
                         LP_plant_loop_idf='plant_loop.idf',
                         idd_file = "C:/EnergyPlusV9-1-0/Energy+.idd"):
    # constants
    BRANCH_TO_DELETE = ['Test room Cooling Coil ChW Branch', 'Test room Heating Coil HW Branch']
    DEMAND_BRANCH_LISTS = ['Hot Water Loop HW Demand Side Branches', 'Chilled Water Loop ChW Demand Side Branches']
    DEMAND_SPLITTER_LISTS = ['Hot Water Loop HW Demand Splitter', 'Chilled Water Loop ChW Demand Splitter']
    DEMAND_MIXER_LISTS = ['Hot Water Loop HW Demand Mixer', 'Chilled Water Loop ChW Demand Mixer']
    OLD_HW_LP_BRANCH_NAME = 'Test room Heating Coil HW Branch'
    OLD_CW_LP_BRANCH_NAME = 'Test room Cooling Coil ChW Branch'
    NEW_HW_LP_BRANCH_NAME = 'Hot Water Loop Load Profile Demand Branch'
    NEW_CW_LP_BRANCH_NAME = 'Chilled Water Loop Load Profile Demand Branch'

    idf_file = expanded_plant_loop_idf
    IDF.setiddname(idd_file)
    idf = IDF(idf_file)

    branches = idf.idfobjects['Branch']
    branche_lists = idf.idfobjects['BranchList']
    splitter_lists = idf.idfobjects['Connector:Splitter']
    mixer_lists = idf.idfobjects['Connector:Mixer']

    # 1. Remove unnecessary objects
    def remove_all_obj_by_type(idf, obj_type_name, exception_name_list=[]):
        if exception_name_list == []:
            idf.idfobjects[obj_type_name] = []
        else:
            old_objcts = idf.idfobjects[obj_type_name]
            idf.idfobjects[obj_type_name] = [obj for obj in old_objcts if obj.Name in exception_name_list]
        return idf

    remove_all_obj_by_type(idf, 'Sizing:Parameters')
    remove_all_obj_by_type(idf, 'ScheduleTypeLimits', ['HVACTemplate Any Number'])
    remove_all_obj_by_type(idf, 'Schedule:Compact', ['HVACTemplate-Always 1', 'HVACTemplate-Always 29.4'])
    remove_all_obj_by_type(idf, 'DesignSpecification:OutdoorAir')
    remove_all_obj_by_type(idf, 'Sizing:Zone')
    remove_all_obj_by_type(idf, 'DesignSpecification:ZoneAirDistribution')
    remove_all_obj_by_type(idf, 'ZoneHVAC:EquipmentConnections')
    remove_all_obj_by_type(idf, 'ZoneHVAC:EquipmentList')
    remove_all_obj_by_type(idf, 'ZoneHVAC:FourPipeFanCoil')
    remove_all_obj_by_type(idf, 'ZoneControl:Thermostat')
    remove_all_obj_by_type(idf, 'Fan:SystemModel')
    remove_all_obj_by_type(idf, 'OutdoorAir:Mixer')
    remove_all_obj_by_type(idf, 'OutdoorAir:NodeList')
    remove_all_obj_by_type(idf, 'Coil:Cooling:Water')
    remove_all_obj_by_type(idf, 'Coil:Heating:Water')
    remove_all_obj_by_type(idf, 'Output:PreprocessorMessage')


    # 2. Delete the old zone coil branch objects
    new_branches = [branch for branch in branches if branch.Name not in BRANCH_TO_DELETE]
    idf.idfobjects['Branch'] = new_branches


    # 3. Rename the demand branches from zone coil branch to load profile branch in the BranchList and  Mixer/Splitter objects
    for branch_list in branche_lists:
        if branch_list.Name in DEMAND_BRANCH_LISTS:
            if branch_list.Branch_2_Name == OLD_HW_LP_BRANCH_NAME:
                branch_list.Branch_2_Name = NEW_HW_LP_BRANCH_NAME
            elif branch_list.Branch_2_Name == OLD_CW_LP_BRANCH_NAME:
                branch_list.Branch_2_Name = NEW_CW_LP_BRANCH_NAME

    for splitter in splitter_lists:
        if splitter.Name in DEMAND_SPLITTER_LISTS:
            if splitter.Outlet_Branch_2_Name == OLD_HW_LP_BRANCH_NAME:
                splitter.Outlet_Branch_2_Name = NEW_HW_LP_BRANCH_NAME
            if splitter.Outlet_Branch_2_Name == OLD_CW_LP_BRANCH_NAME:
                splitter.Outlet_Branch_2_Name = NEW_CW_LP_BRANCH_NAME

    for mixer in mixer_lists:
        if mixer.Name in DEMAND_MIXER_LISTS:
            if mixer.Inlet_Branch_2_Name == OLD_HW_LP_BRANCH_NAME:
                mixer.Inlet_Branch_2_Name = NEW_HW_LP_BRANCH_NAME
            if mixer.Inlet_Branch_2_Name == OLD_CW_LP_BRANCH_NAME:
                mixer.Inlet_Branch_2_Name = NEW_CW_LP_BRANCH_NAME

    # 4. Save the idf.
    idf.saveas(LP_plant_loop_idf)


def append_files(file_1, file_2, file_out):
    base_content = open(file_1, "r").read()
    plant_loop_content = open(file_2, "r").read()
    f_final_content = open(file_out, 'w')
    f_final_content.write(base_content)
    f_final_content.write(plant_loop_content)


def cleanup(file_path):
    if os.path.exists(file_path):
        os.remove(file_path)

def auto_generate_from_template(peak_heating_w, peak_cooling_w, base_LP_idf, base_plant_idf, plant_configuration_json_file, out_dir, final_idf_name, idd_file):
    expanded_plant_loop_idf = 'expanded.idf'
    LP_plant_loop_idf = 'plant_loop.idf'
    temp_base_LP_idf = 'temp_base_LP.idf'

    # Update the flow rate for the loadprofile:plant objects
    IDF.setiddname(idd_file)
    idf = IDF(base_LP_idf)
    idf = auto_update_LP_flow_rates(idf, peak_heating_w, peak_cooling_w)
    idf.saveas(temp_base_LP_idf)
    
    modify_template_idf(plant_configuration_json_file, base_plant_idf, idd_file=idd_file)
    expand_template_idf()
    prepare_LP_plantloop(expanded_plant_loop_idf, LP_plant_loop_idf, idd_file=idd_file)
    append_files(temp_base_LP_idf, LP_plant_loop_idf, final_idf_name)
    cleanup(temp_base_LP_idf)
    cleanup(expanded_plant_loop_idf)
    cleanup(LP_plant_loop_idf)
    cleanup('expandedidf.err')
    cleanup('in.idf')
    if not os.path.exists(out_dir):
        os.mkdir(out_dir)
    shutil.move(final_idf_name, f"{out_dir}{final_idf_name}")


if __name__ == "__main__":
    try:
        print('Creating IDF for system type 1.')
        peak_heating_w = sys.argv[1]
        peak_cooling_w = sys.argv[2]
        base_loadprofile_idf_dir = sys.argv[3]
        base_plant_idf_dir = sys.argv[4]
        plant_configuration_json_dir = sys.argv[5]
        final_idf_dir = sys.argv[6]
        final_idf_name = sys.argv[7]
        idd_file_dir = sys.argv[8]
        auto_generate_from_template(base_loadprofile_idf_dir, base_plant_idf_dir, plant_configuration_json_dir, final_idf_dir, final_idf_name, idd_file_dir)
    except:
        try:
            peak_heating_w = 20000
            peak_cooling_w = 20000
            base_loadprofile_idf_dir = 'base_LP.idf'
            base_plant_idf_dir = 'base_plant.idf'
            plant_configuration_json_dir = 'sys_1_plant_configuration.json'
            final_idf_dir = f'./{datetime.date.today()}/'
            final_idf_name = 'sys_1.idf'
            idd_file_dir = 'Energy+.idd'
            auto_generate_from_template(peak_heating_w, peak_cooling_w, base_loadprofile_idf_dir, base_plant_idf_dir, plant_configuration_json_dir, final_idf_dir, final_idf_name, idd_file_dir)
        except:
            # Show usage instruction
            print('Usage: Python <this_script.py> <peak_heating_w> <peak_cooling_w> <base_loadprofile_idf_dir> <base_plant_idf_dir> <plant_configuration_json_dir> <final_idf_dir> <idd_file_dir>')

