require 'fileutils'
require 'date'
require 'json'
require 'CSV'

class DistrictSystemsController < ApplicationController
  # Class variables, which don't vary by instance
  @@python_command = 'python' # Or full Python command path
  @@ep_exe = 'ep91' # Or full EnergyPlus executable path
  @@idd_file_dir = 'C:/EnergyPlusV9-1-0/Energy+.idd' # IDD path
  @@eplus_electricity_meter = "Electricity:Facility [J](Annual)"
  @@eplus_natural_gas_meter = "Gas:Facility [J](Annual)"

  @@root_path = File.expand_path("..", File.dirname(File.dirname(__FILE__)))
  @@user_uploads_path = @@root_path + '/public/user_uploads/'
  @@output_files_path = @@root_path + '/public/output_files/'
  @@dhc_template_path = @@root_path + '/public/dhc_templates/'
  @@idf_modifier_py = @@root_path + '/public/idf_modifier.py'
  @@idf_runner_py = @@root_path + '/public/idf_runner.py'
  @@run_path = @@root_path + '/public/runs/'
  @@sys_type_1_idf_name = 'sys_1.idf'
  @@sys_type_2_idf_name = 'sys_2.idf'
  @@sys_type_3_idf_name = 'sys_3.idf'
  @@sys_type_4_idf_name = 'sys_4.idf'
  @@sys_type_5_idf_name = 'sys_5.idf'
  @@sys_type_1_name = "Water-cooled Chillers + Boiler"
  @@sys_type_2_name = "Water-cooled Chillers with Ice-Storage + Boiler"
  @@sys_type_3_name = "Heat-recovery Chillers + Heat Pumps"
  @@sys_type_4_name = "Geothermal Heat Pump"
  @@sys_type_5_name = "Combined Heat and Power System (under development)"
  @@sys_type_1_dev = false
  @@sys_type_2_dev = false
  @@sys_type_3_dev = false
  @@sys_type_4_dev = false
  @@sys_type_5_dev = true


  # Instance variables
  @sys_type_1_selected = false
  @sys_type_2_selected = false
  @sys_type_3_selected = false
  @sys_type_4_selected = false
  @sys_type_5_selected = false


  def J_to_kWh(joule_value)
    joule_value / 3600000
  end

  def J_to_kBTU(joule_value)
    joule_value * 0.000947817
  end

  def index
    puts '---> Entering Index...'
    # TODO: keep visualization, simulation configurations, and simulation results in session for quicker rendering.
    @error_message = {}
    @tabs = tab_control(true, false, false)
    @system_types = add_system_types
  end

  def dispatcher
    @error_message = {}
    # TODO: Handle post requests differently depending on their purpose (e.g., upload, visualize, simulate)
    if params[:load_profile_csv]
      upload_file(params)
    elsif params[:district_system_config]
      simulate(params)
    end
  end

  def upload_file(params)
    puts '---> Entering Upload method...'
    #TODO: Handle file uploaded, consider saving to database in the future
    puts '------> User uploaded a CSV, save it to session, and visualize it.'
    @tabs = tab_control(true, false, false)
    # Move the uploaded file to the ./public/user_uploads path
    old_file_path = params[:load_profile_csv].path
    filename = File.basename(old_file_path)
    new_file_path = @@user_uploads_path + filename
    FileUtils.cp(old_file_path, new_file_path) if File.exist?(old_file_path)
    session[:uploaded_file_path] = new_file_path
    @system_types = add_system_types
    render "index"
  end

  def simulate(params)
    puts '---> Entering Simulate method...'
    @tabs = tab_control(false, true, false)

    # Check if a epw file is available, show error message if none exists.
    puts '-' * 100
    if session[:weather_epw_path].nil? and params[:weather_epw].nil?
      puts 'Will show no weather file error message!'
    elsif params[:weather_epw].nil? and not session[:weather_epw_path].nil?
      puts 'Will use weather file in session'
      old_epw_path = session[:weather_epw_path]
      filename = File.basename(session[:weather_epw_path])
      new_epw_path = @@user_uploads_path + filename
    else
      puts 'Will use user uploaded weather file'
      old_epw_path = params[:weather_epw].path
      filename = params[:weather_epw].original_filename
      new_epw_path = @@user_uploads_path + filename
    end

    # Copy the uploaded weather file to the temp run folder
    FileUtils.cp(old_epw_path, new_epw_path) if File.exist?(old_epw_path)
    session[:weather_epw_path] = new_epw_path
    @weather_epw_name = filename

    #TODO: 1. Prepare simulation configurations (IDFs, schedule:files, commands)
    # Need to automate this process, consider quick-check to adjust default plant loop, branches settings.
    jobs_json_dir = prepare_simulation(params)

    #TODO: 2. Call EnergyPlus simulation for the district heating and cooling systems.
    # A Python routine to call simulation in parallel is ready
    simulation_success = false

    puts jobs_json_dir

    unless jobs_json_dir.nil?
      simulation_success = run_simulate(jobs_json_dir)
    end

    #TODO: 3. Post-process the simulation results, prepare it as a hash, render it to the view.
    puts "Simulations are successful = #{simulation_success}"
    @simulation_results = params[:district_system_config]
    jobs_json_hash = JSON.parse(File.read(jobs_json_dir))
    puts "Simulations are done in: #{jobs_json_hash['run dir']}"

    v_results = []
    jobs_json_hash['jobs'].each do |job|
      job_out_csv = job['run_dir'] + '/eplusout.csv'
      out_hash = read_eplus_output(job_out_csv)
      out_hash['sys_type'] = job['sys_type']
      v_results.push(out_hash)
    end

    @v_results = v_results

    # TODO: Set conditions

    @tabs = tab_control(false, false, true)
    @system_types = add_system_types
    render "index" # TODO: figure out how to set active tab in the view.
  end


  ######################################################################################################################
  # Helper methods
  ######################################################################################################################
  def add_system_types()
    v_system_types = []
    v_system_types.push([@@sys_type_1_name, @@sys_type_1_dev, @sys_type_1_selected])
    v_system_types.push([@@sys_type_2_name, @@sys_type_2_dev, @sys_type_2_selected])
    v_system_types.push([@@sys_type_3_name, @@sys_type_3_dev, @sys_type_3_selected])
    v_system_types.push([@@sys_type_4_name, @@sys_type_4_dev, @sys_type_4_selected])
    v_system_types.push([@@sys_type_5_name, @@sys_type_5_dev, @sys_type_5_selected])
    return v_system_types
  end

  def prepare_simulation(params)
    puts '#' * 100
    puts 'Preparing simulations...'
    @sys_type_1_selected = params[:district_system_config][:system_type_1] == '1' ? true : false
    @sys_type_2_selected = params[:district_system_config][:system_type_2] == '1' ? true : false
    @sys_type_3_selected = params[:district_system_config][:system_type_3] == '1' ? true : false
    @sys_type_4_selected = params[:district_system_config][:system_type_4] == '1' ? true : false
    @sys_type_5_selected = params[:district_system_config][:system_type_5] == '1' ? true : false
    v_selections = [@sys_type_1_selected, @sys_type_2_selected, @sys_type_3_selected, @sys_type_4_selected, @sys_type_5_selected]

    uploaded_sch = session[:uploaded_file_path]
    uploaded_epw = session[:weather_epw_path]
    puts uploaded_sch
    puts uploaded_epw
    jobs_json_dir = nil

    if v_selections.all? { |x| x == false }
      @error_message[:error] = 'At least one system type should be selected for simulation.'
      @tabs = tab_control(false, true, false)
    elsif uploaded_sch.nil?
      @error_message[:error] = 'Make sure the heating and cooling demand data is uploaded.'
      @tabs = tab_control(false, true, false)
    elsif uploaded_epw.nil?
      @error_message[:error] = 'Make sure the weather file is uploaded.'
      @tabs = tab_control(false, true, false)
    else
      # Create a folder in the run_dir and copy the files to it.
      temp_run_path = @@run_path + 'run_' + DateTime.now.strftime('%Q') + '/'
      Dir.mkdir(temp_run_path) unless File.exists?(temp_run_path)

      run_epw_file = temp_run_path + File.basename(uploaded_epw)
      run_sch_file = temp_run_path + File.basename(uploaded_sch)

      FileUtils.cp(uploaded_sch, run_sch_file) # The user-uploaded schedule:file CSV
      FileUtils.cp(uploaded_epw, run_epw_file) # The user-uploaded epw file

      v_simulation_jobs = []

      if @sys_type_1_selected
        sys_1_idf = temp_run_path + @@sys_type_1_idf_name
        sys_1_run_dir = temp_run_path + 'sys_1'
        FileUtils.cp(@@dhc_template_path + @@sys_type_1_idf_name, sys_1_idf)
        idf_modifier(@@python_command, @@idf_modifier_py, sys_1_idf, run_epw_file, run_sch_file, @@idd_file_dir)
        v_simulation_jobs.push(create_simulation_job_hash(@@ep_exe, run_epw_file, sys_1_idf, sys_1_run_dir, @@sys_type_1_name))
      end
      if @sys_type_2_selected
        sys_2_idf = temp_run_path + @@sys_type_2_idf_name
        sys_2_run_dir = temp_run_path + 'sys_2'
        FileUtils.cp(@@dhc_template_path + @@sys_type_2_idf_name, sys_2_idf)
        idf_modifier(@@python_command, @@idf_modifier_py, sys_2_idf, run_epw_file, run_sch_file, @@idd_file_dir)
        v_simulation_jobs.push(create_simulation_job_hash(@@ep_exe, run_epw_file, sys_2_idf, sys_2_run_dir, @@sys_type_2_name))
      end
      if @sys_type_3_selected
        sys_3_idf = temp_run_path + @@sys_type_3_idf_name
        sys_3_run_dir = temp_run_path + 'sys_3'
        FileUtils.cp(@@dhc_template_path + @@sys_type_3_idf_name, sys_3_idf)
        idf_modifier(@@python_command, @@idf_modifier_py, sys_3_idf, run_epw_file, run_sch_file, @@idd_file_dir)
        v_simulation_jobs.push(create_simulation_job_hash(@@ep_exe, run_epw_file, sys_3_idf, sys_3_run_dir, @@sys_type_3_name))
      end
      if @sys_type_4_selected
        sys_4_idf = temp_run_path + @@sys_type_4_idf_name
        sys_4_run_dir = temp_run_path + 'sys_4'
        FileUtils.cp(@@dhc_template_path + @@sys_type_4_idf_name, sys_4_idf)
        idf_modifier(@@python_command, @@idf_modifier_py, sys_4_idf, run_epw_file, run_sch_file, @@idd_file_dir)
        v_simulation_jobs.push(create_simulation_job_hash(@@ep_exe, run_epw_file, sys_4_idf, sys_4_run_dir, @@sys_type_4_name))
      end
      if @sys_type_5_selected
        sys_5_idf = temp_run_path + @@sys_type_5_idf_name
        sys_5_run_dir = temp_run_path + 'sys_5'
        FileUtils.cp(@@dhc_template_path + @@sys_type_5_idf_name, sys_5_idf)
        idf_modifier(@@python_command, @@idf_modifier_py, sys_5_idf, run_epw_file, run_sch_file, @@idd_file_dir)
        v_simulation_jobs.push(create_simulation_job_hash(@@ep_exe, run_epw_file, sys_5_idf, sys_5_run_dir, @@sys_type_5_name))
      end

      # Prepare the json file as simulation input
      job_hash = {
          "Date" => "Some date",
          "jobs" => v_simulation_jobs,
          "run dir" => temp_run_path,
      }
      jobs_json_dir = "#{temp_run_path}jobs.json"
      File.open(jobs_json_dir, "w") do |f|
        f.write(job_hash.to_json)
      end
    end
    return jobs_json_dir
  end

  def run_simulate(jobs_json_dir)
    begin
      run_command = "#{@@python_command} #{@@idf_runner_py} #{jobs_json_dir}"
      puts '~' * 100
      puts run_command
      pid = spawn(run_command)
      Process.wait pid
      success = true
    rescue
      success = false
    end
    return success
  end

  def idf_modifier(python_command, py_script, idf_file_dir, epw_file_dir, sch_file_dir, idd_file_dir)
    pid = spawn("#{python_command} #{py_script} #{idf_file_dir} #{epw_file_dir} #{sch_file_dir} #{idd_file_dir}")
    Process.wait pid
  end

  def create_simulation_job_hash(ep_exe, epw_file, idf_file, run_dir, sys_type)
    job_hash = {
        "ep_exe" => ep_exe,
        "epw_file" => epw_file,
        "idf_file" => idf_file,
        "run_dir" => run_dir,
        "sys_type" => sys_type,
    }
    return job_hash
  end

  def read_eplus_output(eplusout_dir)
    # This function read the eplusout.csv file and create a result hash.
    csv_table = CSV.read(eplusout_dir, headers: true)

    # There might be white spaces in the csv headers
    real_electricity_header = nil
    real_natural_gas_header = nil
    csv_table.headers.each do |header|
      if header.include? @@eplus_electricity_meter
        real_electricity_header = header
      elsif header.include? @@eplus_natural_gas_meter
        real_natural_gas_header = header
      end
    end
    if real_electricity_header.nil?
      real_electricity_header = @@eplus_electricity_meter
    end
    if real_natural_gas_header.nil?
      real_natural_gas_header = @@eplus_natural_gas_meter
    end

    out_hash = {
        "annual electricity" => J_to_kWh(csv_table[0][real_electricity_header].to_f),
        "annual gas" => J_to_kBTU(csv_table[0][real_natural_gas_header].to_f),
    }
    out_hash
  end

  def tab_control(upload_active = true, config_active = false, result_active = false)
    tabs = {}
    if upload_active
      tabs[:upload_link_control] = 'active'
      tabs[:config_link_control] = ''
      tabs[:result_link_control] = ''
      tabs[:upload_tab_control] = 'show active'
      tabs[:config_tab_control] = ''
      tabs[:result_tab_control] = ''
    elsif config_active
      tabs[:upload_link_control] = ''
      tabs[:config_link_control] = 'active'
      tabs[:result_link_control] = ''
      tabs[:upload_tab_control] = ''
      tabs[:config_tab_control] = 'show active'
      tabs[:result_tab_control] = ''
    elsif result_active
      tabs[:upload_link_control] = ''
      tabs[:config_link_control] = ''
      tabs[:result_link_control] = 'active'
      tabs[:upload_tab_control] = ''
      tabs[:config_tab_control] = ''
      tabs[:result_tab_control] = 'show active'
    end
    tabs
  end

  ######################################################################################################################
  # Methods may be useful in future
  ######################################################################################################################
  def new
    # Not needed for the stand-alone simulation function for now.

  end

  def create

  end

end
