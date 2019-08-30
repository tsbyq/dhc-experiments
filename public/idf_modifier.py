import sys
from eppy.modeleditor import IDF


def modify_schedule_file_path(idf_file_dir,
                              epw_file_dir,
                              sch_file_dir,
                              idd_file_dir="C:/EnergyPlusV9-1-0/Energy+.idd"
                              ):

    IDF.setiddname(idd_file_dir)
    idf = IDF(idf_file_dir, epw_file_dir)

    v_sch_files = idf.idfobjects['schedule:file']
    for sch_file in v_sch_files:
        sch_file.File_Name = sch_file_dir

    idf.save(idf_file_dir)
    print('Modifications completed.')


if __name__ == "__main__":
    try:
        print(sys.argv[1])
        print(sys.argv[2])
        print(sys.argv[3])
        print(sys.argv[4])
        idf_file_dir = sys.argv[1]
        epw_file_dir = sys.argv[2]
        sch_file_dir = sys.argv[3]
        idd_file_dir = sys.argv[4]
        modify_schedule_file_path(
            idf_file_dir, epw_file_dir, sch_file_dir, idd_file_dir)
    except:
        # Show usage instruction
        print('Usage: Python <this_script.py> <idf_file_dir> <epw_file_dir> <sch_file_dir> <idd_file_dir>')
