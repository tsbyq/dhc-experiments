class DistrictSystemsController < ApplicationController
  @district_system_config = {}

  def index
    puts 'GET request...'
    # TODO: keep visualization, simulation configurations, and simulation results in session for quicker rendering.
    @simulation_results = {}
  end

  def dispatcher
    # TODO: Handle post requests differently depending on their purpose (e.g., upload, visualize, simulate)
    puts "The dispatcher received a POST request..."
    if params[:load_profile_csv]
      upload_file(params)
    elsif params[:district_system_config]
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
    #TODO: 1. Prepare simulation configurations (IDFs, schedule:files, commands)
    # Need to automate this process, consider quick-check to adjust default plant loop, branches settings.

    #TODO: 2. Call EnergyPlus simulation for the district heating and cooling systems.
    # A Python routine to call simulation in parallel is ready

    #TODO: 3. Post-process the simulation results, prepare it as a hash, render it to the view.

    puts '%' * 100
    puts 'Entering simulate method of the DistrictSystem controller...'
    puts 'User provided DHC simulation configurations, run it...'

    puts '*' * 90
    puts params
    puts '*' * 90
    # puts @simulation_results
    @simulation_results = params[:district_system_config]
    puts params[:district_system_config]
    render "district_systems/index" # TODO: figure out how to set active tab in the view.
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
