import eppy
import copy

from eppy.modeleditor import IDF

BRANCH_TO_DELETE = ['Test room Cooling Coil ChW Branch', 'Test room Heating Coil HW Branch']
DEMAND_BRANCH_LISTS = ['Hot Water Loop HW Demand Side Branches', 'Chilled Water Loop ChW Demand Side Branches']
DEMAND_SPLITTER_LISTS = ['Hot Water Loop HW Demand Splitter', 'Chilled Water Loop ChW Demand Splitter']
DEMAND_MIXER_LISTS = ['Hot Water Loop HW Demand Mixer', 'Chilled Water Loop ChW Demand Mixer']

OLD_HW_LP_BRANCH_NAME = 'Test room Heating Coil HW Branch'
OLD_CW_LP_BRANCH_NAME = 'Test room Cooling Coil ChW Branch'
NEW_HW_LP_BRANCH_NAME = 'Hot Water Loop Load Profile Demand Branch'
NEW_CW_LP_BRANCH_NAME = 'Chilled Water Loop Load Profile Demand Branch'

idd_file = "C:/EnergyPlusV9-1-0/Energy+.idd"
idf_file = "expanded.idf"
epw_file = "in.epw"

IDF.setiddname(idd_file)
idf = IDF(idf_file, epw_file)

branches = idf.idfobjects['Branch']
branche_lists = idf.idfobjects['BranchList']
splitter_lists = idf.idfobjects['Connector:Splitter']
mixer_lists = idf.idfobjects['Connector:Mixer']

# idf.printidf()
print('---Before---')
# print(idf.idfobjects['Sizing:Parameters'])
# print(idf.idfobjects['ScheduleTypeLimits'])
# print(idf.idfobjects['Schedule:Compact']) # Keep "HVACTemplate-Always 29.4" and "HVACTemplate-Always 1"
# print(idf.idfobjects['DesignSpecification:OutdoorAir'])
# print(idf.idfobjects['Sizing:Zone'])
# print(idf.idfobjects['DesignSpecification:ZoneAirDistribution'])
# print(idf.idfobjects['ZoneHVAC:EquipmentConnections'])
# print(idf.idfobjects['ZoneHVAC:EquipmentList'])
# print(idf.idfobjects['ZoneHVAC:FourPipeFanCoil'])
# print(idf.idfobjects['Fan:SystemModel'])
# print(idf.idfobjects['OutdoorAir:Mixer'])
# print(idf.idfobjects['OutdoorAir:NodeList'])
# print(idf.idfobjects['Coil:Cooling:Water'])
# print(idf.idfobjects['Coil:Heating:Water'])

# 1. Remove unnecessary objects
def remove_all_obj_by_type(idf, obj_type_name, exception_name_list=[]):
    if exception_name_list == []:
        idf.idfobjects[obj_type_name] = []
    else:
        old_objcts = idf.idfobjects[obj_type_name]
        idf.idfobjects[obj_type_name] = [obj for obj in old_objcts if obj.Name in exception_name_list]
    return idf

remove_all_obj_by_type(idf, 'Sizing:Parameters')
remove_all_obj_by_type(idf, 'ScheduleTypeLimits')
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
idf.saveas('plant_loop.idf')