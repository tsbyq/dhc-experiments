require 'fileutils'
require 'date'
require 'json'
require 'CSV'
require 'Time'

class DistrictSystemsController < ApplicationController
  # Class variables, which don't vary by instance
  @@python_command = 'python' # Or full Python command path
  @@ep_exe = 'ep91' # Or full EnergyPlus executable path
  @@idd_file_dir = 'C:/EnergyPlusV9-1-0/Energy+.idd' # IDD path

  @@eplus_electricity_meter_annual = "Electricity:Facility [J](Annual)"
  @@eplus_natural_gas_meter_annual = "Gas:Facility [J](Annual)"
  @@eplus_electricity_meter_hourly = "Electricity:Facility [J](Hourly)"
  @@eplus_natural_gas_meter_hourly = "Gas:Facility [J](Hourly)"
  @@eplus_cooling_demand_variable = "PlantLoopCoolingDemand:Facility [J](Hourly)"
  @@eplus_heating_demand_variable = "PlantLoopHeatingDemand:Facility [J](Hourly)"

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

  # The unit cost of fuels will be available in CityBES
  @@ele_unit_cost = 0.042 # $/kWh
  @@gas_unit_cost = 151 # $/MMBTU

  # Instance variables
  @sys_type_1_selected = false
  @sys_type_2_selected = false
  @sys_type_3_selected = false
  @sys_type_4_selected = false
  @sys_type_5_selected = false

  def J_to_kWh(joule_value)
    joule_value / 3600000
  end

  def J_to_mmbtu(joule_value)
    joule_value * 0.000000000947817
  end

  def index
    puts '---> Entering Index...'
    # TODO: keep visualization, simulation configurations, and simulation results in session for quicker rendering.
    @error_message = {}
    if session[:tabs].nil?
      @tabs = tab_control(true, false, false)
    else
      @tabs = session[:tabs]
    end
    @system_types = add_system_types
    @hash_key_stats = session[:hash_key_stats]
    @hash_ts_data = session[:hash_ts_data]
    @v_results = session[:v_results]
    @v_results_js = session[:v_results_js]
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
    session[:hash_key_stats] = ''
    puts '---> Entering Upload method...'
    #TODO: Handle file uploaded, consider saving to database in the future
    puts '------> User uploaded a CSV, save it to session, and visualize it.'
    # Move the uploaded file to the ./public/user_uploads path
    old_file_path = params[:load_profile_csv].path
    filename = File.basename(old_file_path)
    new_file_path = @@user_uploads_path + filename
    FileUtils.cp(old_file_path, new_file_path) if File.exist?(old_file_path)
    session[:uploaded_file_path] = new_file_path
    session[:hash_ts_data], session[:hash_key_stats] = read_upload_csv(new_file_path)
    @system_types = add_system_types
    session[:tabs] = tab_control(true, false, false)
    redirect_to :action => "index"
  end

  def simulate(params)
    puts '---> Entering Simulate method...'
    # Check if a epw file is available, show error message if none exists.
    old_epw_path = params[:weather_epw].path
    filename = params[:weather_epw].original_filename
    new_epw_path = @@user_uploads_path + filename
    # Copy the uploaded weather file to the temp run folder
    FileUtils.cp(old_epw_path, new_epw_path) if File.exist?(old_epw_path)
    session[:weather_epw_path] = new_epw_path
    @weather_epw_name = filename

    #TODO: 1. Prepare simulation configurations (IDFs, schedule:files, commands)
    # Need to automate this process, consider quick-check to adjust default plant loop, branches settings.
    jobs_json_dir, hash_incremental_cost = prepare_simulation(params)

    #TODO: 2. Call EnergyPlus simulation for the district heating and cooling systems.
    # A Python routine to call simulation in parallel is ready
    simulation_success = false

    puts jobs_json_dir
    puts hash_incremental_cost

    unless jobs_json_dir.nil?
      simulation_success = run_simulate(jobs_json_dir)
    end

    #TODO: 3. Post-process the simulation results, prepare it as a hash, render it to the view.
    puts "Simulations are successful = #{simulation_success}"
    @simulation_results = params[:district_system_config]
    jobs_json_hash = JSON.parse(File.read(jobs_json_dir))
    puts "Simulations are done in: #{jobs_json_hash['run dir']}"

    v_results = []
    base_out_hash = {
        "sys_type" => 'Baseline',
        "annual electricity" => session[:base_annual_ele_consumption],
        "annual gas" => session[:base_annual_gas_consumption],
        "peak hourly ele consumption" => session[:base_peak_ele_consumption],
        "annual electricity saving" => 0,
        "annual utility cost" => session[:base_annual_ele_consumption] * @@ele_unit_cost + session[:base_annual_gas_consumption] * @@gas_unit_cost,
        "annual utility cost saving" => 0,
        "hourly electricity peak reduction" => 0,
        "annual gas saving" => 0,
        "incremental cost" => 0,
        'simple payback' => 0,
    }
    v_results.push(base_out_hash)

    jobs_json_hash['jobs'].each do |job|
      job_out_csv = job['run_dir'] + '/eplusout.csv'
      out_hash = read_eplus_output(job_out_csv)
      out_hash['sys_type'] = job['sys_type']
      out_hash["annual electricity saving"] = base_out_hash['annual electricity'] - out_hash["annual electricity"]
      out_hash["annual gas saving"] = base_out_hash['annual gas'] - out_hash["annual gas"]
      out_hash["hourly electricity peak reduction"] = base_out_hash["peak hourly ele consumption"].to_f - out_hash["peak hourly ele consumption"].to_f
      out_hash['incremental cost'] = hash_incremental_cost[job['sys_type']]
      out_hash['annual utility cost'] = out_hash["annual electricity"] * @@ele_unit_cost + out_hash["annual gas"] * @@gas_unit_cost
      out_hash['annual utility cost saving'] = base_out_hash['annual utility cost'] - out_hash['annual utility cost']
      out_hash['simple payback'] = out_hash['incremental cost'].to_f / out_hash['annual utility cost saving'].to_f
      v_results.push(out_hash)
    end

    puts '=' * 100
    puts v_results
    puts '=' * 100

    session[:v_results] = v_results
    session[:v_results_js] = v_results.to_json.html_safe
    @system_types = add_system_types
    session[:tabs] = tab_control(false, false, true)
    redirect_to :action => "index"
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
    hash_incremental_cost = Hash.new
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
        hash_incremental_cost[@@sys_type_1_name] = params[:district_system_config][:incremental_cost_system_type_1]
        FileUtils.cp(@@dhc_template_path + @@sys_type_1_idf_name, sys_1_idf)
        idf_modifier(@@python_command, @@idf_modifier_py, sys_1_idf, run_epw_file, run_sch_file, @@idd_file_dir)
        v_simulation_jobs.push(create_simulation_job_hash(@@ep_exe, run_epw_file, sys_1_idf, sys_1_run_dir, @@sys_type_1_name))
      end
      if @sys_type_2_selected
        sys_2_idf = temp_run_path + @@sys_type_2_idf_name
        sys_2_run_dir = temp_run_path + 'sys_2'
        hash_incremental_cost[@@sys_type_2_name] = params[:district_system_config][:incremental_cost_system_type_2]
        FileUtils.cp(@@dhc_template_path + @@sys_type_2_idf_name, sys_2_idf)
        idf_modifier(@@python_command, @@idf_modifier_py, sys_2_idf, run_epw_file, run_sch_file, @@idd_file_dir)
        v_simulation_jobs.push(create_simulation_job_hash(@@ep_exe, run_epw_file, sys_2_idf, sys_2_run_dir, @@sys_type_2_name))
      end
      if @sys_type_3_selected
        sys_3_idf = temp_run_path + @@sys_type_3_idf_name
        sys_3_run_dir = temp_run_path + 'sys_3'
        hash_incremental_cost[@@sys_type_3_name] = params[:district_system_config][:incremental_cost_system_type_3]
        FileUtils.cp(@@dhc_template_path + @@sys_type_3_idf_name, sys_3_idf)
        idf_modifier(@@python_command, @@idf_modifier_py, sys_3_idf, run_epw_file, run_sch_file, @@idd_file_dir)
        v_simulation_jobs.push(create_simulation_job_hash(@@ep_exe, run_epw_file, sys_3_idf, sys_3_run_dir, @@sys_type_3_name))
      end
      if @sys_type_4_selected
        sys_4_idf = temp_run_path + @@sys_type_4_idf_name
        sys_4_run_dir = temp_run_path + 'sys_4'
        hash_incremental_cost[@@sys_type_4_name] = params[:district_system_config][:incremental_cost_system_type_4]
        FileUtils.cp(@@dhc_template_path + @@sys_type_4_idf_name, sys_4_idf)
        idf_modifier(@@python_command, @@idf_modifier_py, sys_4_idf, run_epw_file, run_sch_file, @@idd_file_dir)
        v_simulation_jobs.push(create_simulation_job_hash(@@ep_exe, run_epw_file, sys_4_idf, sys_4_run_dir, @@sys_type_4_name))
      end
      if @sys_type_5_selected
        sys_5_idf = temp_run_path + @@sys_type_5_idf_name
        sys_5_run_dir = temp_run_path + 'sys_5'
        hash_incremental_cost[@@sys_type_5_name] = params[:district_system_config][:incremental_cost_system_type_5]
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
    return [jobs_json_dir, hash_incremental_cost]
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

  def read_upload_csv(csv_path)
    v_time = []
    v_heating_demand = []
    v_cooling_demand = []
    v_sim_heating_cooling_demand = []
    v_ele_consumption = []
    v_gas_consumption = []

    v_time_millisecond = []
    v_heating_demand_ts = []
    v_cooling_demand_ts = []
    v_sim_heating_cooling_demand_ts = []
    v_ele_consumption_ts = []
    v_gas_consumption_ts = []

    CSV.foreach(csv_path).with_index do |row, i|
      next if i == 0
      datetime, heat_demand, cool_demand, ele_consumption, gas_consumption, new_date_time = row

      time_millisecond = (Time.strptime(new_date_time, "%m/%d/%Y %H:%M").to_f * 1000).to_i

      v_time << new_date_time
      v_ele_consumption << ele_consumption.to_f
      v_gas_consumption << gas_consumption.to_f
      v_heating_demand << heat_demand.to_f
      v_cooling_demand << cool_demand.to_f
      v_sim_heating_cooling_demand << [heat_demand.to_f, heat_demand.to_f.abs].min

      # Prepare time-series data
      v_time_millisecond << time_millisecond
      v_heating_demand_ts << [time_millisecond, heat_demand.to_f]
      v_cooling_demand_ts << [time_millisecond, cool_demand.to_f]
      v_sim_heating_cooling_demand_ts << [time_millisecond, [heat_demand.to_f, cool_demand.to_f.abs].min]
      v_ele_consumption_ts << [time_millisecond, ele_consumption.to_f]
      v_gas_consumption_ts << [time_millisecond, gas_consumption.to_f]
    end

    hash_ts_data = {
        "v_heating_demand_ts" => v_heating_demand_ts,
        "v_cooling_demand_ts" => v_cooling_demand_ts,
        "v_sim_heating_cooling_demand_ts" => v_sim_heating_cooling_demand_ts,
        "v_ele_consumption_ts" => v_ele_consumption_ts,
        "v_gas_consumption_ts" => v_gas_consumption_ts,
    }

    # Prepare key statistics
    annual_ele_consumption = v_ele_consumption.sum
    annual_gas_consumption = v_gas_consumption.sum
    session[:base_annual_ele_consumption] = annual_ele_consumption
    session[:base_annual_gas_consumption] = annual_gas_consumption
    session[:base_peak_ele_consumption] = v_ele_consumption.max

    peak_heating_demand = v_heating_demand.max
    peak_cooling_demand = v_cooling_demand.min
    peak_sim_heating_cooling_demand = v_sim_heating_cooling_demand.max
    peak_ele_consumption = v_ele_consumption.max
    peak_gas_consumption = v_gas_consumption.max

    peak_heating_demand_timestamp = v_time[v_heating_demand.index(peak_heating_demand)]
    peak_cooling_demand_timestamp = v_time[v_cooling_demand.index(peak_cooling_demand)]
    peak_sim_heating_cooling_demand_timestamp = v_time[v_sim_heating_cooling_demand.index(peak_sim_heating_cooling_demand)]
    peak_ele_consumption_timestamp = v_time[v_ele_consumption.index(peak_ele_consumption)]
    peak_gas_consumption_timestamp = v_time[v_gas_consumption.index(peak_gas_consumption)]

    heating_demand_diversity = (simpson_diversity_index(v_heating_demand) * 100).round(1)
    cooling_demand_diversity = (simpson_diversity_index(v_cooling_demand) * 100).round(1)
    sim_heating_cooling_demand_diversity = (simpson_diversity_index(v_sim_heating_cooling_demand) * 100).round(1)
    ele_consumption_diversity = (simpson_diversity_index(v_ele_consumption) * 100).round(1)
    gas_consumption_diversity = (simpson_diversity_index(v_gas_consumption) * 100).round(1)

    heating_demand_intensity = 1
    cooling_demand_intensity = 1
    sim_heating_cooling_demand_intensity = 1
    ele_consumption_intensity = 1
    gas_consumption_intensity = 1

    hash_key_stats = {
        "annual electricity consumption" => annual_ele_consumption,
        "annual natural gas consumption" => annual_gas_consumption,

        "peak heating demand" => peak_heating_demand,
        "peak cooling demand" => peak_cooling_demand,
        "peak sim heating and cooling demand" => peak_sim_heating_cooling_demand,
        "peak electricity consumption" => peak_ele_consumption,
        "peak natural gas consumption" => peak_gas_consumption,

        "peak heating demand time" => peak_heating_demand_timestamp,
        "peak cooling demand time" => peak_cooling_demand_timestamp,
        "peak sim heating and cooling demand time" => peak_sim_heating_cooling_demand_timestamp,
        "peak electricity consumption time" => peak_ele_consumption_timestamp,
        "peak natural gas consumption time" => peak_gas_consumption_timestamp,

        "heating demand intensity" => heating_demand_intensity,
        "cooling demand intensity" => cooling_demand_intensity,
        "sim heating and cooling demand intensity" => sim_heating_cooling_demand_intensity,
        "ele consumption intensity" => ele_consumption_intensity,
        "gas consumption intensity" => gas_consumption_intensity,

        "heating demand diversity" => heating_demand_diversity,
        "cooling demand diversity" => cooling_demand_diversity,
        "sim heating and cooling demand diversity" => sim_heating_cooling_demand_diversity,
        "ele consumption diversity" => ele_consumption_diversity,
        "gas consumption diversity" => gas_consumption_diversity,
    }

    return [hash_ts_data, hash_key_stats]
  end

  def read_eplus_output(eplusout_dir)
    # This function read the eplusout.csv file and create a result hash.
    csv_table = CSV.read(eplusout_dir, headers: true)

    # There might be white spaces in the csv headers
    real_electricity_annual_header = nil
    real_natural_gas_annual_header = nil
    real_electricity_hourly_header = nil
    real_natural_gas_hourly_header = nil
    real_heating_demand_header = nil
    real_cooling_demand_header = nil

    csv_table.headers.each do |header|
      if header.include? @@eplus_electricity_meter_annual
        real_electricity_annual_header = header
      elsif header.include? @@eplus_natural_gas_meter_annual
        real_natural_gas_annual_header = header
      elsif header.include? @@eplus_electricity_meter_hourly
        real_electricity_hourly_header = header
      elsif header.include? @@eplus_natural_gas_meter_hourly
        real_natural_gas_hourly_header = header
      elsif header.include? @@eplus_heating_demand_variable
        real_heating_demand_header = header
      elsif header.include? @@eplus_cooling_demand_variable
        real_cooling_demand_header = header
      end
    end

    if real_electricity_annual_header.nil?
      real_electricity_annual_header = @@eplus_electricity_meter_annual
    end
    if real_natural_gas_annual_header.nil?
      real_natural_gas_annual_header = @@eplus_natural_gas_meter_annual
    end
    if real_electricity_hourly_header.nil?
      real_electricity_hourly_header = @@eplus_electricity_meter_hourly
    end
    if real_natural_gas_hourly_header.nil?
      real_natural_gas_hourly_header = @@eplus_natural_gas_meter_hourly
    end
    if real_heating_demand_header.nil?
      real_heating_demand_header = @@eplus_heating_demand_variable
    end
    if real_cooling_demand_header.nil?
      real_cooling_demand_header = @@eplus_cooling_demand_variable
    end

    out_hash = {
        "annual electricity" => J_to_kWh(csv_table[real_electricity_annual_header][-1].to_f),
        "annual gas" => J_to_mmbtu(csv_table[real_natural_gas_annual_header][-1].to_f),

        # "hourly electricity" => csv_table[real_electricity_hourly_header],
        # "hourly gas" => csv_table[real_natural_gas_hourly_header],

        "peak hourly ele consumption" => J_to_kWh(csv_table[real_electricity_hourly_header].max.to_f),
        "peak hourly gas consumption" => J_to_mmbtu(csv_table[real_natural_gas_hourly_header].max.to_f),

        # "cooling demand" => csv_table[real_cooling_demand_header],
        # "heating demand" => csv_table[real_heating_demand_header],
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

  def simpson_diversity_index(v_in, chunk_size = 200)
    lower = v_in.min
    upper = v_in.max + chunk_size
    temp_lower = lower
    temp_upper = lower + chunk_size
    v_counts = []
    v_in = v_in.sort
    i = 0
    while temp_upper <= upper do
      j = i
      count = 0
      while true
        if v_in[j] >= temp_lower and v_in[j] < temp_upper and j < v_in.length - 1
          count += 1
          j += 1
        else
          break
        end
      end
      if count > 0
        v_counts << count
      end
      i = j
      temp_lower = temp_upper
      temp_upper += chunk_size
    end

    numerator = 0
    denominator = v_in.length * (v_in.length - 1)
    v_counts.each do |current_count|
      numerator += current_count * (current_count - 1)
    end
    return 1 - numerator.to_f / denominator.to_f
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
