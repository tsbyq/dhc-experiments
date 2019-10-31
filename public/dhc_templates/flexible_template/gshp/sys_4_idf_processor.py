import eppy
import sys
import json
from eppy.modeleditor import IDF

def auto_update_LP_flow_rates(idf, peak_heating_w, peak_cooling_w):
    # This function calculates and updates the peak flow rates of the LoadProfile:Plant objects
    CP_WATER = 4186 # J/(kg*C)
    DELTA_T_H = 30 # C
    DELTA_T_C = 2 # C
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

def auto_update_ghex_system(idf, peak_heating_w, peak_cooling_w, heating_cop, cooling_cop, n_borehole, soil_k):
    # This function calculates and updates the properties of the GHEX
    W_2_TON = 0.0002843
    GPM_2_M3S = 0.000063090196
    GPM_PER_TON = 3 # usually 3gpm GHEX flow rate per ton of capacity
    SIZING_FACTOR = 1.5

    # 1. Design flow rate
    v_flow_ghex_design = max(abs(peak_heating_w), abs(peak_cooling_w)) * W_2_TON * GPM_PER_TON * GPM_2_M3S
    idf.idfobjects['GroundHeatExchanger:System'][0].Design_Flow_Rate = v_flow_ghex_design

    # 2. Number of Borehole
    idf.idfobjects['GroundHeatExchanger:ResponseFactors'][0].Number_of_Boreholes = n_borehole

    # 3. Heating and cooling capacities and power consumptions
    idf.idfobjects['HeatPump:WaterToWater:EquationFit:Heating'][0].Reference_Heating_Capacity = abs(peak_heating_w) * SIZING_FACTOR
    idf.idfobjects['HeatPump:WaterToWater:EquationFit:Heating'][0].Reference_Heating_Power_Consumption = abs(peak_heating_w) * SIZING_FACTOR / heating_cop
    idf.idfobjects['HeatPump:WaterToWater:EquationFit:Cooling'][0].Reference_Cooling_Capacity = abs(peak_cooling_w) * SIZING_FACTOR
    idf.idfobjects['HeatPump:WaterToWater:EquationFit:Cooling'][0].Reference_Cooling_Power_Consumption = abs(peak_cooling_w) * SIZING_FACTOR / cooling_cop

    # 4. Condenser loop max flow rate
    # idf.idfobjects['CondenserLoop'][0].Maximum_Loop_Flow_Rate = v_flow_ghex_design
    idf.idfobjects['CondenserLoop'][0].Maximum_Loop_Flow_Rate = 1

    # 5. Soild thermal conductivity [W/(m*K]
    idf.idfobjects['Site:GroundTemperature:Undisturbed:KusudaAchenbach'][0].Soil_Thermal_Conductivity = soil_k

    return idf



def auto_generate_from_template(peak_heating_w, 
                                peak_cooling_w, 
                                heating_cop, 
                                cooling_cop, 
                                n_borehole, 
                                soil_k, 
                                base_idf_dir, 
                                final_idf_dir, 
                                idd_file_dir):

    IDF.setiddname(idd_file_dir)
    idf = IDF(base_idf_dir)

    idf = auto_update_LP_flow_rates(idf, peak_heating_w, peak_cooling_w)
    idf = auto_update_ghex_system(idf, peak_heating_w, peak_cooling_w, heating_cop, cooling_cop, n_borehole, soil_k)

    idf.save(final_idf_dir)
 


if __name__ == "__main__":
    try:
        print('Creating IDF for system type 4.')
        peak_heating_w = sys.argv[1]
        peak_cooling_w = sys.argv[2]
        heating_cop = sys.argv[3]
        cooling_cop = sys.argv[4]
        n_borehole = sys.argv[5]
        soil_k = sys.argv[6]
        base_idf_dir = sys.argv[7]
        final_idf_dir = sys.argv[8]
        idd_file_dir = sys.argv[9]
        auto_generate_from_template(peak_heating_w, peak_cooling_w, heating_cop, cooling_cop, n_borehole, soil_k, base_idf_dir, final_idf_dir, idd_file_dir)
    
    except:
        # Show usage instruction
        print('Usage: Python <this_script.py> <peak_heating_w>, <peak_cooling_w>, <heating_cop>, <cooling_cop>, <n_borehole>, <soil_k>, <base_idf_dir>, <final_idf_dir>, <idd_file_dir>')