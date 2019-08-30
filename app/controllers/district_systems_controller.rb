require 'fileutils'
require 'date'

class DistrictSystemsController < ApplicationController
  @@root_path = File.expand_path("..", File.dirname(File.dirname(__FILE__)))
  @@user_uploads_path = @@root_path + '/public/user_uploads/'
  @@output_files_path = @@root_path + '/public/output_files/'
  @@dhc_template_path = @@root_path + '/public/dhc_templates/'
  @@run_path = @@root_path + '/public/runs/'
  @@sys_type_1_idf_name = 'sys_1.idf'
  @@sys_type_2_idf_name = 'sys_2.idf'
  @@sys_type_3_idf_name = 'sys_3.idf'
  @@sys_type_4_idf_name = 'sys_4.idf'
  @@sys_type_5_idf_name = 'sys_5.idf'

  def index
    puts '---> Entering Index...'
    # TODO: keep visualization, simulation configurations, and simulation results in session for quicker rendering.
    @error_message = {}
    @tabs = tab_control(true, false, false)
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
    render "index"
  end

  def simulate(params)
    puts '---> Entering Simulate method...'
    @tabs = tab_control(false, true, false)
    old_epw_path = params[:weather_epw].path
    filename = File.basename(old_epw_path)
    new_epw_path = @@user_uploads_path + filename

    FileUtils.cp(old_epw_path, new_epw_path) if File.exist?(old_epw_path)
    session[:weather_epw_path] = new_epw_path

    #TODO: 1. Prepare simulation configurations (IDFs, schedule:files, commands)
    # Need to automate this process, consider quick-check to adjust default plant loop, branches settings.
    prepare_simulation(params)


    #TODO: 2. Call EnergyPlus simulation for the district heating and cooling systems.
    # A Python routine to call simulation in parallel is ready

    #TODO: 3. Post-process the simulation results, prepare it as a hash, render it to the view.
    # Discuss which outputs are needed.
    @simulation_results = params[:district_system_config]

    # TODO: Set conditions


    render "index" # TODO: figure out how to set active tab in the view.
  end


  ######################################################################################################################
  # Helper methods
  ######################################################################################################################
  def prepare_simulation(params)
    puts '#' * 100
    puts 'Preparing simulations...'
    selected_sys_type_1 = params[:district_system_config][:system_type_1]
    selected_sys_type_2 = params[:district_system_config][:system_type_2]
    selected_sys_type_3 = params[:district_system_config][:system_type_3]
    selected_sys_type_4 = params[:district_system_config][:system_type_4]
    selected_sys_type_5 = params[:district_system_config][:system_type_5]
    v_selections = [selected_sys_type_1, selected_sys_type_2, selected_sys_type_3, selected_sys_type_4, selected_sys_type_5]

    uploaded_file = session[:uploaded_file_path]
    uploaded_epw = session[:weather_epw_path]
    puts uploaded_file
    puts uploaded_epw

    if v_selections.all? { |x| x == "0" }
      @error_message[:error] = 'At least one system type should be selected for simulation.'
      @tabs = tab_control(false, true, false)
    elsif uploaded_file.nil?
      @error_message[:error] = 'Make sure the heating and cooling demand data is uploaded.'
      @tabs = tab_control(false, true, false)
    elsif uploaded_epw.nil?
      @error_message[:error] = 'Make sure the weather file is uploaded.'
      @tabs = tab_control(false, true, false)
    else
      puts 'Do something'
      # Create a folder in the run_dir and copy the files to it.
      temp_run_path = @@run_path + 'run_' + DateTime.now.strftime('%Q') +'/'
      Dir.mkdir(temp_run_path) unless File.exists?(temp_run_path)

      FileUtils.cp(uploaded_file, temp_run_path + File.basename(uploaded_file))
      FileUtils.cp(uploaded_epw, temp_run_path + File.basename(uploaded_epw))

      if selected_sys_type_1 == '1'
        FileUtils.cp(@@dhc_template_path + @@sys_type_1_idf_name, temp_run_path + @@sys_type_1_idf_name)
      end
      if selected_sys_type_2 == '1'
        FileUtils.cp(@@dhc_template_path + @@sys_type_2_idf_name, temp_run_path + @@sys_type_2_idf_name)
      end
      if selected_sys_type_3 == '1'
        FileUtils.cp(@@dhc_template_path + @@sys_type_3_idf_name, temp_run_path + @@sys_type_3_idf_name)
      end
      if selected_sys_type_4 == '1'
        FileUtils.cp(@@dhc_template_path + @@sys_type_4_idf_name, temp_run_path + @@sys_type_4_idf_name)
      end
      if selected_sys_type_5 == '1'
        FileUtils.cp(@@dhc_template_path + @@sys_type_5_idf_name, temp_run_path + @@sys_type_5_idf_name)
      end
    end

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
