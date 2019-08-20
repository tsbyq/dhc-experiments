class DistrictSystemsController < ApplicationController
  @district_system_config = {}

  def index
    puts 'GET request...'

  end

  def new

  end

  def create
    @district_system_config = params
    render plain: params[:district_system].inspect
    puts @district_system_config
  end

  def simulate
    puts 'POST request'
    @simulation_results = {
        a: '123',
        b: '345',
    }
    render plain: params[:district_system].inspect
  end

end
