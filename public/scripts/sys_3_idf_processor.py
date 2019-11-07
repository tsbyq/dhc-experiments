import eppy
import sys
from eppy.modeleditor import IDF

def auto_update_LP_flow_rates(idf, peak_heating_w, peak_cooling_w):
    # This function calculates and updates the peak flow rates of the LoadProfile:Plant objects
    CP_WATER = 4186 # J/(kg*C)
    DELTA_T_H = 10 # C
    DELTA_T_C = 5 # C
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


def auto_generate_from_template(peak_heating_w, peak_cooling_w, cop, number, base_idf_dir, final_idf_dir, idd_file_dir):
    IDF.setiddname(idd_file_dir)
    idf = IDF(base_idf_dir)
    idf.idfobjects['ChillerHeaterPerformance:Electric:EIR'][0].Reference_Cooling_Mode_COP = cop
    idf.idfobjects['CentralHeatPumpSystem'][0].Number_of_Chiller_Heater_Modules_1 = number
    idf = auto_update_LP_flow_rates(idf, peak_heating_w, peak_cooling_w)
    idf.save(final_idf_dir)


if __name__ == "__main__":
    try:
        print('Creating IDF for system type 3.')
        peak_heating_w = float(sys.argv[1])
        peak_cooling_w = float(sys.argv[2])
        cop = sys.argv[3]
        number = sys.argv[4]
        base_idf_dir = sys.argv[5]
        final_idf_dir = sys.argv[6]
        idd_file_dir = sys.argv[7]
        auto_generate_from_template(peak_heating_w, peak_cooling_w, cop, number, base_idf_dir, final_idf_dir, idd_file_dir)
    except:
        # Show usage instruction
        print('Usage: Python <this_script.py> <peak_heating_w> <peak_cooling_w> <cop> <number> <base_idf_dir> <final_idf_dir> <idd_file_dir>')