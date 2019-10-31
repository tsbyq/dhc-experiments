import eppy
import sys
from eppy.modeleditor import IDF

def auto_generate_from_template(cop, number, base_idf_dir, final_idf_dir, idd_file_dir):
    IDF.setiddname(idd_file_dir)
    idf = IDF(base_idf_dir)
    idf.idfobjects['ChillerHeaterPerformance:Electric:EIR'][0].Reference_Cooling_Mode_COP = cop
    idf.idfobjects['CentralHeatPumpSystem'][0].Number_of_Chiller_Heater_Modules_1 = number
    idf.save(final_idf_dir)


if __name__ == "__main__":
    try:
        print('Creating IDF for system type 3.')
        cop = sys.argv[1]
        number = sys.argv[2]
        base_idf_dir = sys.argv[3]
        final_idf_dir = sys.argv[4]
        idd_file_dir = sys.argv[5]
        auto_generate_from_template(cop, number, base_idf_dir, final_idf_dir, idd_file_dir)
    except:
        # Show usage instruction
        print('Usage: Python <this_script.py> <cop> <number> <base_idf_dir> <final_idf_dir> <idd_file_dir>')