import eppy
import copy

from eppy.modeleditor import IDF


def modify_template_idf(base_template_idf, modified_template_idf):
    return

def expand_template_idf(template_idf, expanded_template_idf):
    return

def prepare_LP_plantloop(expanded_plant_loop_idf='expanded.idf', LP_plant_loop_idf='plant_loop.idf'):
    BRANCH_TO_DELETE = ['Test room Cooling Coil ChW Branch', 'Test room Heating Coil HW Branch']
    DEMAND_BRANCH_LISTS = ['Hot Water Loop HW Demand Side Branches', 'Chilled Water Loop ChW Demand Side Branches']
    DEMAND_SPLITTER_LISTS = ['Hot Water Loop HW Demand Splitter', 'Chilled Water Loop ChW Demand Splitter']
    DEMAND_MIXER_LISTS = ['Hot Water Loop HW Demand Mixer', 'Chilled Water Loop ChW Demand Mixer']
    
    OLD_HW_LP_BRANCH_NAME = 'Test room Heating Coil HW Branch'
    OLD_CW_LP_BRANCH_NAME = 'Test room Cooling Coil ChW Branch'
    NEW_HW_LP_BRANCH_NAME = 'Hot Water Loop Load Profile Demand Branch'
    NEW_CW_LP_BRANCH_NAME = 'Chilled Water Loop Load Profile Demand Branch'
    
    idd_file = "C:/EnergyPlusV9-1-0/Energy+.idd"
    idf_file = expanded_plant_loop_idf
    epw_file = "in.epw"
    
    IDF.setiddname(idd_file)
    idf = IDF(idf_file, epw_file)
    
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
    idf.saveas(LP_plant_loop_idf)


def append_files(file_1, file_2, file_out):
    base_content = open(file_1, "r").read()
    plant_loop_content = open(file_2, "r").read()
    f_final_content = open(file_out, 'w')
    f_final_content.write(base_content)
    f_final_content.write(plant_loop_content)


if __name__ == '__main__':
    base_LP_idf = 'base.idf'
    expanded_plant_loop_idf = 'expanded.idf'
    LP_plant_loop_idf = 'plant_loop.idf'
    final_idf = 'final_999.idf'
    prepare_LP_plantloop(expanded_plant_loop_idf, LP_plant_loop_idf)
    append_files(base_LP_idf, LP_plant_loop_idf, final_idf)