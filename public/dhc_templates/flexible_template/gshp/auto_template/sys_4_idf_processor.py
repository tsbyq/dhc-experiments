import eppy
import sys
from eppy.modeleditor import IDF

def auto_update_LP_flow_rates(idf, peak_heating_w, peak_cooling_w):
    # This function calculates and updates the peak flow rates of the LoadProfile:Plant objects
    CP_WATER = 4186 # J/(kg*C)
    DELTA_T = 8 # C 
    RHO_WATER = 1000 #kg/m3
    SAFE_FACTOR = 1.5

    v_peak_flow_heating = abs(peak_cooling_w)/(CP_WATER * DELTA_T * RHO_WATER) # peak flow rate (m3/s)
    v_peak_flow_cooling = abs(peak_heating_w)/(CP_WATER * DELTA_T * RHO_WATER) # peak flow rate (m3/s)
    v_lp = idf.idfobjects['LoadProfile:Plant']
    for lp in v_lp:
        if lp.Name == "District Heating Load Profile":
            lp.Peak_Flow_Rate = v_peak_flow_heating * SAFE_FACTOR
        elif lp.Name == "District Cooling Load Profile":
            lp.Peak_Flow_Rate = v_peak_flow_cooling * SAFE_FACTOR

    idf.idfobjects['LoadProfile:Plant'] = v_lp
    return idf

def auto_update_ghex_flow_rate(idf, peak_heating_w, peak_cooling_w):
    # This function calculates and updates the design flow rate of the GHEX
    W_2_TON = 0.0002843
    GPM_2_M3S = 0.000063090196
    GPM_PER_TON = 3 # usually 3gpm GHEX flow rate per ton of capacity

    v_flow_ghex_design = max(abs(peak_heating_w), abs(peak_cooling_w)) * W_2_TON * GPM_PER_TON * GPM_2_M3S
    idf.idfobjects['GroundHeatExchanger:System'][0].Design_Flow_Rate = v_flow_ghex_design
    return idf


def auto_generate_from_template(dict_lp, heating_cop, cooling_cop, n_borehole, base_idf_dir, final_idf_dir, idd_file_dir):



    IDF.setiddname(idd_file_dir)
    idf = IDF(base_idf_dir)

    peak_cooling_w = dict_lp["peak_cooling_w"]
    peak_heating_w = dict_lp["peak_heating_w"]

    idf = auto_update_LP_flow_rates(idf, peak_heating_w, peak_cooling_w)
    idf = auto_update_ghex_flow_rate(idf, peak_heating_w, peak_cooling_w)

    # idf.idfobjects['ChillerHeaterPerformance:Electric:EIR'][0].Reference_Cooling_Mode_COP = cop
    # idf.idfobjects['ChillerHeaterPerformance:Electric:EIR'][0].Reference_Cooling_Mode_COP = cop


    # print(idf.idfobjects['GroundHeatExchanger:System'][0].Design_Flow_Rate)
    
    idf.save(final_idf_dir)


dict_lp = {"peak_cooling_w": -5377435, "peak_heating_w": 6947019}
heating_cop = 3
cooling_cop = 4
n_borehole = 400
base_idf_dir = "sys_4_base.idf"
final_idf_dir = "sys_4_out.idf"
idd_file_dir = "C:/EnergyPlusV9-1-0/Energy+.idd"   
auto_generate_from_template(dict_lp, heating_cop, cooling_cop, n_borehole, base_idf_dir, final_idf_dir, idd_file_dir)

# if __name__ == "__main__":
#     try:
#         print('Creating IDF for system type 4.')
#         # cop = sys.argv[1]
#         # number = sys.argv[2]
#         # base_idf_dir = sys.argv[3]
#         # final_idf_dir = sys.argv[4]
#         # idd_file_dir = sys.argv[5]
#         dict_lp = {"peak_cooling_w": -5377435, "peak_heating_w": 6947019}
#         heating_cop = 3
#         cooling_cop = 4
#         n_borehole = 400
#         base_idf_dir = "sys_4_base.idf"
#         final_idf_dir = "sys_4_out.idf"
#         idd_file_dir = "C:/EnergyPlusV9-1-0/Energy+.idd"     
          
#         auto_generate_from_template(dict_lp, heating_cop, cooling_cop, n_borehole, base_idf_dir, final_idf_dir, idd_file_dir)
#     except:
#         # Show usage instruction
#         print('Usage: Python <this_script.py> <cop> <number> <base_idf_dir> <final_idf_dir> <idd_file_dir>')