using JuMP, AxisArrays, Gurobi, UnPack, StatsPlots, Colors, Statistics, CSV, DataFrames, Plots, PrettyTables

include("ElectricitySystemModel.jl")
include("Input.jl")
include("Helpfunctions.jl")

#//////////////////////////////////////////////////////////////////////////////////////////////////
"""
read_input(problem)

Prepare model inputs and constants.
- Builds sets: REGION, TECH, PLANT, PERIOD
- Defines the energy storage capacity (in TWh) for different types of hydropower facilities in each region
- Defines the minimum allowable energy level for hydropower reservoirs in each country
- Loads static tables (max capacities, transmission, distances)
- Defines technology parameters (costs, efficiencies, lifetimes, emissions)
- Computes derived values (CRF, transmission costs, etc.)

Arguments:
- problem: a `TModelParameters` struct with fields like `time_step`, `input_data_length`, `use_mean_aggregation`, `transmission_grid`.

Returns: a named tuple with all input arrays and parameters required by the model.
"""
function read_input(problem)
    println("\nReading Input Data...")
    @unpack time_step, input_data_length, use_mean_aggregation, transmission_grid = problem
    no_periods = div(input_data_length, time_step)
    
    # Sets
    PERIOD = 1:no_periods
    REGION = [:NO, :SE, :FI, :DK, :IE, :UK, :NL, :BE, :LU, :DE, :PL, :LV, :EE, :LT, :CZ, :AT, :SK, :HU, :FR, :CH, :IT, :SI, :HR, :RO, :BG, :GR, :ES, :PT]    
    TECH = [:HydroRes, :HydroRoR, :PSHopenTurb, :PSHopenPump, :PSHclosedTurb, :PSHclosedPump, :Gas, :Wind, :OffWind, :PV, :RooftopPV, :Battery, :Inverter, :Nuclear, :Electrolyzer, :H2Storage, :H2GT]
    PLANT = [:HydroRes, :HydroRoR, :Gas, :Wind, :OffWind, :PV, :RooftopPV, :Nuclear] 
    
    # Parameters
    no_regions = length(REGION)
    no_plants = length(PLANT)
    no_techs = length(TECH)
    
    # HydroRes Energy Cap:      NO      SE      FI    DK IE UK NL BE LU DE     PL     LV EE LT CZ     AT     SK     HU FR      CH     IT     SI HR     RO    BG     GR     ES      PT
    hydroreservoir = AxisArray([71.875, 31.931, 5.53, 0, 0, 0, 0, 0, 0, 0.237, 0.001, 0, 0, 0, 0.002, 0.769, 0.017, 0, 10.057, 7.912, 5.488, 0, 2.046, 2.34, 0.843, 4.044, 14.775, 1.29], REGION) # [TWh]
    
    # PSHopen Energy Cap:        NO      SE FI DK IE UK NL BE LU DE     PL     LV EE LT CZ     AT     SK     HU FR    CH     IT     SI HR     RO     BG     GR     ES     PT
    PSopenReservoir = AxisArray([15.453, 0, 0, 0, 0, 0, 0, 0, 0, 0.438, 0.001, 0, 0, 0, 0.003, 1.747, 0.048, 0, 0.09, 1.194, 0.299, 0, 0.018, 1.033, 0.042, 0.005, 5.764, 2.018], REGION) # [TWh]

    # PSHclosed Energy Cap:        NO SE FI DK IE     UK     NL BE     LU     DE     PL     LV EE LT     CZ     AT     SK     HU FR    CH     IT     SI     HR RO BG     GR     ES     PT
    PSclosedReservoir = AxisArray([0, 0, 0, 0, 0.004, 0.026, 0, 0.012, 0.005, 0.276, 0.006, 0, 0, 0.011, 0.004, 0.004, 0.008, 0, 0.01, 0.056, 0.061, 0.004, 0, 0, 0.228, 0.004, 0.101, 0], REGION) # [TWh]

                                  # NO      SE     FI     DK IE UK     NL BE LU DE     PL     LV     EE LT     CZ AT     SK     HU FR     CH     IT     SI     HR     RO     BG     GR     ES     PT
    min_reservoir_level = AxisArray([0.217, 0.165, 0.284, 0, 0, 0.165, 0, 0, 0, 0.165, 0.165, 0.165, 0, 0.025, 0, 0.084, 0.165, 0, 0.089, 0.053, 0.233, 0.165, 0.087, 0.115, 0.265, 0.466, 0.259, 0.264], REGION)

    # PLANT's Max Capacity
    maxcap_df = CSV.read(joinpath(dirname(@__FILE__), "maxcaptable.csv"), DataFrame)    # Read maxcap data from CSV [GW]
    maxcap_matrix = Matrix(maxcap_df[:, 2:end])                                         # Convert to matrix & exclude first column (Plant names)
    maxcap = AxisArray(maxcap_matrix' .* 1000, REGION, TECH)                            # Create AxisArray & transpose to match dimensions - Convert to MW
    
    techtable = [
                # PLANT               Inv. Cost      fixedcost      Variable Cost   Fuel Cost       Efficiency      Lifetime        Emissionfactor
                # -                   €/MW           €/MW/year      €/MWh_elec      €/MWh_fuel      -               yrs             ton/MWh
                :HydroRes             0              22082          0               0               0.9             80              0  
                :HydroRoR             0              66245          0               0               0.9             80              0  
                :PSHopenTurb          0              11041          0               0               0.87            80              0       # Fixed cost split between Turb & Pump
                :PSHopenPump          0              11041          0               0               0.87            80              0
                :PSHclosedTurb        0              11041          0               0               0.87            80              0
                :PSHclosedPump        0              11041          0               0               0.87            80              0
                :Gas                  436e3          7893           4.79            22              0.43            25              0.202   # from DEA
                :Wind                 1090e3         15602          1.85            0               1               30              0  
                :OffWind              1640e3         33000          3.25            0               1               30              0
                :PV                   290e3          9900           0               0               1               40              0 
                :RooftopPV            410e3          7500           0               0               1               40              0 
                :Battery              65e3           0              0               0               1               15              0       # Inv. Cost in [€/MWh]
                :Inverter             200e3          38000          0               0               0.85            15              0  
                :Nuclear              5000e3         126000         3.5             2.6             0.33            40              0  
                :Electrolyzer         300e3          12000          0               0               0.7             25              0
                :H2Storage            22e3           425            0               0               0.9             30              0    
                :H2GT                 760e3          11000          2.4             0               0.6             25              0       # CCGT 
                ]
        
        
    techdata = Float64.(techtable[:,2:end])
    inv_cost = AxisArray(techdata[:,1] , TECH)
    fixed_cost = AxisArray(techdata[:,2] , TECH)
    var_cost = AxisArray(techdata[:,3], TECH)    
    fuel_cost = AxisArray(techdata[:,4], TECH)      
    eta = AxisArray(techdata[:,5], TECH)        
    lifetime = AxisArray(techdata[:,6], TECH)
    emissionfactor = AxisArray(techdata[:,7], TECH)

    # Transmission
    distance_df = CSV.read(joinpath(dirname(@__FILE__), "Transmission", "distance.csv"), DataFrame; header=false, skipto=2, limit=28)       # Read the CSV file into a DataFrame, skipping the header and reading only the range B2:AC29
    distance_matrix = Matrix(distance_df[:, 2:end])     # Extract columns B to AC (indices 2 to 29)
    distance = NamedArray(distance_matrix, (REGION, REGION))

    valid_links_df = CSV.read(joinpath(dirname(@__FILE__), "Transmission", "valid_links.csv"), DataFrame; header=false, skipto=2, limit=28)
    valid_links_matrix = Matrix(valid_links_df[:, 2:end])
    valid_links = NamedArray(valid_links_matrix, (REGION, REGION))

    # Reference transmission grid (upper limit)
    max_transmission_df = CSV.read(joinpath(dirname(@__FILE__), "Transmission", string(transmission_grid, "_grid.csv")), DataFrame; header=false, skipto=2, limit=28)   # e.g., "2025_grid.csv" or "2040_grid.csv"
    max_transmission_matrix = Matrix(max_transmission_df[:, 2:end])
    max_transmission = NamedArray(max_transmission_matrix, (REGION, REGION))

    loss_per_K_Km = 0.016
    discountrate = 0.05
    crf = AxisArray(discountrate ./ (1 .- 1 ./(1 + discountrate).^lifetime), TECH)
    
    transmissioncost = 400  # €/MW/km
    crf_t=discountrate ./ (1 .- 1 ./(1 + discountrate).^40)
    
    discharge_time = 4  # hours
    
    return (; REGION, PLANT, TECH, PERIOD, no_regions, no_plants, no_techs, no_periods, 
            inv_cost, fixed_cost, var_cost, fuel_cost, eta, discharge_time, 
            emissionfactor, crf, maxcap, hydroreservoir, PSopenReservoir, PSclosedReservoir, min_reservoir_level, transmissioncost, valid_links, distance, max_transmission, loss_per_K_Km, crf_t) # 
    end
#//////////////////////////////////////////////////////////////////////////////////////////////////

"""
main()

Main entry point for running the model end-to-end:
1. Create a `problem` (model / scenario) parameter struct
2. Read static inputs and time-series
3. Build and solve the stochastic model (and optionally simulate results)
4. Save summary tables to an HTML file

Modify the `problem` fields above to run different experiments.
"""
function main()
    println("Starting main function...")

    problem = TModelParameters(
    carbon_cap = 10/1e3,    # tonCO2/MWh
    storage = true,
    transmission = true,
    transmission_constrained = true,    # whether the transmission grid capacities are constrained
    transmission_grid = "2025",     # "2025" or "2040" - valid if transmission_constrained = true
    nuclear = true,  
    input_data_length = 365*24,
    time_step = 7,  # hours   
    load_shedding_cost = 1000,  # €/MWh %
    loss_of_load_penalty = 100000,  # €/MWh %
    load_shedding_ratio = 0.05, 
    use_mean_aggregation = false,
    fix_hydro = true,
    planned_outage_rate = 0.15,
    stochastic_model_scenarios = [1996, 2016],   # years to include as scenarios in the stochastic model (between 1979 and 2018)
    scenario_probability = [1, 1],     # prob. will be normalized - must have same number of items as scenarios
    solve_stochastic_model = true,
    simulate_results = false    # whether to simulate the results after solving the stochastic model
    ) 
    
    println("Problem parameters set.")
    input = read_input(problem)
    println("Input data read.")
    time_series_data = ReadTimeSeriesData(problem, input)
    println("Time series data read.")

    # Here we solve the stochastic model
    if problem.solve_stochastic_model
        println("\nSolving stochastic model")
        stochastic_model_scenario_data = ReadScenarioData(problem.stochastic_model_scenarios, problem.scenario_probability, problem, input, time_series_data)
        stochastic_solution_results = SolveStochasticModel(problem, input, stochastic_model_scenario_data, time_series_data)
        # Automatically save results with different names
        grid_label = problem.transmission_constrained ? problem.transmission_grid : "unconstrained"
        filename = problem.simulate_results ? ("fullresults_" * grid_label * "grid_" * join(string.(problem.stochastic_model_scenarios), "_")) : ("results_" * grid_label * "grid_" * join(string.(problem.stochastic_model_scenarios), "_"))
        SaveAllTables(filename, stochastic_solution_results.tables)     # if more details needed, replace 'filename' with 'filename * "_..."'
    end

    return nothing
end

@time main()

