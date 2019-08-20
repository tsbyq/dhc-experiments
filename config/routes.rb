Rails.application.routes.draw do
  # get 'district_systems/index'

  get 'welcome/index'

  get "district_systems", to: "district_systems#index"

  post "district_systems", to: "district_systems#simulate"

  root to: 'welcome#index'
end
