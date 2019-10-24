import sys
import subprocess
import os
from multiprocessing import Pool
import json


def run_single(v_args):
    ep_exe, idf_file, epw_file, run_dir = v_args
    out_dir = os.path.abspath(run_dir)
    if not os.path.exists(out_dir):
        os.makedirs(out_dir)
    cmd = [ep_exe, '-w', epw_file, '-r', idf_file]
    p = subprocess.Popen(cmd, cwd=out_dir)
    p.wait()


def run_batch(v_args_dicts, max_n_parallel=5):

    # Prepare the function argument list
    v_cmd_list_new = [[arg_dict['ep_exe'], arg_dict['idf_file'],
                       arg_dict['epw_file'], arg_dict['run_dir']] for arg_dict in v_args_dicts]
    n_total_runs = len(v_cmd_list_new)

    print('All jobs list = ' + str(v_cmd_list_new))

    # Batch simulation with parallelization.
    i = 0
    while i + max_n_parallel <= n_total_runs:
        print('#' * 80)
        print('Simulating job: ' + str(list(range(i, i+max_n_parallel))))
        # print(v_cmd_list_new[i:i+max_n_parallel])
        # Do not recommend too large number of processes
        pool = Pool(processes=max_n_parallel)
        pool.map(run_single, v_cmd_list_new[i:i+max_n_parallel])
        pool.close()
        pool.join()
        i += max_n_parallel

    # Finished the remaining processes if there is any.
    if n_total_runs - i > 0:
        print('#' * 80)
        print('Simulating job: ' + str(list(range(i, n_total_runs))))
        # print(v_cmd_list_new[i:n_total_runs])
        # Do not recommend too large number of processes
        pool = Pool(processes=n_total_runs - i)
        pool.map(run_single, v_cmd_list_new[i:n_total_runs])
        pool.close()
        pool.join()


################################################################################
if __name__ == '__main__':
    try:
        jobs_json_dir = sys.argv[1]
        print(f"Running jobs: {jobs_json_dir}")
        with open(jobs_json_dir) as json_file:
            data = json.load(json_file)
            v_args_dicts = data['jobs']
            run_batch(v_args_dicts)
        print('All simulation completed.')
    except:
        # Show usage instruction
        print('Usage: Python <this_script.py> <jobs_json_dir>')
