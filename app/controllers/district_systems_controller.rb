class DistrictSystemsController < ApplicationController
  @district_system_config = {}

  def index
    puts 'GET request...'
    # TODO:Get simulation results from session
    @simulation_results = {}
    puts @simulation_results
  end

  def new

  end

  def create

  end

  def dispatcher
    # TODO: Handle post requests differently depending on their purpose (e.g., upload, visualize, simulate)
    puts "Do something here!"
    puts params


    if params[:load_profile_csv]
      upload_file(params)
    elsif params[:district_system_config]
      simulate(params)
    end
  end

  def upload_file(params)
    #TODO: Handle file uploaded, consider saving to database in the future
    puts 'User uploaded a CSV, visualize it...'
    puts '*' * 90
    puts params
    puts '*' * 90

    uploaded_file = params[:load_profile_csv]
    puts uploaded_file.path
    puts uploaded_file.original_filename

  end

  def visualize
    #TODO: Visualize the CSV file use uploaded

  end

  def simulate(params)
    #TODO: Call EnergyPlus simulation for the district heating and cooling systems
    puts 'User provided DHC simulation configurations, run it...'
    @simulation_results = {
        a: '123',
        b: '345',
    }
    @simulation_results = params[:district_system_config]
    # render plain: params[:district_system].inspect
  end


end
