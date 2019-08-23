class DistrictSystemsController < ApplicationController
  @district_system_config = {}
  @tabs = {}

  def index
    puts 'GET request...'
    # TODO: keep visualization, simulation configurations, and simulation results in session for quicker rendering.
    @simulation_results = {}
    @tabs = tab_control(true, false, false)
  end

  def dispatcher
    # TODO: Handle post requests differently depending on their purpose (e.g., upload, visualize, simulate)
    puts "The dispatcher received a POST request..."
    if params[:load_profile_csv]
      @tabs = tab_control(true, false, false)
      upload_file(params)
    elsif params[:district_system_config]
      @tabs = tab_control(false, true, false)
      simulate(params)
    end
  end

  def upload_file(params)
    #TODO: Handle file uploaded, consider saving to database in the future
    puts 'User uploaded a CSV, do something with it...'
    uploaded_file = params[:load_profile_csv]

    puts uploaded_file.path
    puts uploaded_file.original_filename
  end

  def simulate(params)
    puts '%' * 100
    puts 'Entering simulate method of the DistrictSystem controller...'
    puts 'User provided DHC simulation configurations, run it...'

    puts '*' * 90
    puts params
    puts '*' * 90
    # puts @simulation_results
    @simulation_results = params[:district_system_config]
    puts params[:district_system_config]


    #TODO: 1. Prepare simulation configurations (IDFs, schedule:files, commands)
    # Need to automate this process, consider quick-check to adjust default plant loop, branches settings.

    #TODO: 2. Call EnergyPlus simulation for the district heating and cooling systems.
    # A Python routine to call simulation in parallel is ready

    #TODO: 3. Post-process the simulation results, prepare it as a hash, render it to the view.
    # Discuss which outputs are needed.


    # TODO: Set conditions
    @tabs = tab_control(false, false, true)

    render "index" # TODO: figure out how to set active tab in the view.
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
