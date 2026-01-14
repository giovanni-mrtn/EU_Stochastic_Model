using CSV, DataFrames, AxisArrays, UnPack, NamedArrays, Random, Statistics

include("Helpfunctions.jl")

#//////////////////////////////////////////////////////////////////////////////////////////////////
"""
ReadScenarioData(selected_scenarios, scenario_probability, problem, input, time_series_data)

Map a list of selected historical years into model scenarios.
- `selected_scenarios`: vector of years (e.g. [1997, 2004, 2012])
- `scenario_probability`: relative weights (same length)

Returns: SCENARIO index set, per-scenario `cf`, `load`, `res_inflow`, `ror_inflow`, `PS_inflow`, and `prob` (normalized probabilities).
"""
function ReadScenarioData(selected_scenarios, scenario_probability, problem, input, time_series_data)
    @unpack time_step = problem
    @unpack REGION, PERIOD, PLANT, no_regions, no_plants, no_periods = input
    @unpack simulated_cf, simulated_load, simulated_res_inflow, simulated_ror_inflow, simulated_PS_inflow = time_series_data 
    no_scenarios = length(selected_scenarios)
    SCENARIO = 1:no_scenarios
    
    load = AxisArray(zeros(no_scenarios, no_regions, no_periods), SCENARIO, REGION, PERIOD)
    res_inflow = AxisArray(zeros(no_scenarios, no_regions, no_periods), SCENARIO, REGION, PERIOD)
    ror_inflow = AxisArray(zeros(no_scenarios, no_regions, no_periods), SCENARIO, REGION, PERIOD)
    PS_inflow = AxisArray(zeros(no_scenarios, no_regions, no_periods), SCENARIO, REGION, PERIOD)
    prob = AxisArray(ones(no_scenarios)./no_scenarios, SCENARIO)
    cf = AxisArray(ones(no_scenarios, no_regions, no_plants, no_periods), SCENARIO, REGION, PLANT, PERIOD)
    
    
    SumProb=sum(scenario_probability)
    for s in SCENARIO
        prob[s] = scenario_probability[s]/SumProb
        index = selected_scenarios[s] - 1979 + 1
        cf[s, :, :Wind, :] = simulated_cf[index , :, :Wind, :]
        cf[s, :, :OffWind, :] = simulated_cf[index , :, :OffWind, :]
        cf[s, :, :PV, :] = simulated_cf[index, :, :PV, :]
        cf[s, :, :RooftopPV, :] = simulated_cf[index, :, :RooftopPV, :]
        load[s, :, :] = simulated_load[index, :, :]
        res_inflow[s, :, :] = simulated_res_inflow[index, :, :] 
        ror_inflow[s, :, :] = simulated_ror_inflow[index, :, :]
        PS_inflow[s, :, :] = simulated_PS_inflow[index, :, :]
    end

    return(; SCENARIO, no_scenarios, cf, load, res_inflow, ror_inflow, PS_inflow, prob)
end

#//////////////////////////////////////////////////////////////////////////////////////////////////
"""
prepare_simulation_data(problem, input, time_series_data, weather_selected_index)

Extract single-year time series for deterministic simulation runs.
Returns `cf`, `load`, and inflows for the chosen `weather_selected_index` (index into SIMULATION_YEARS).

Used only when `problem.simulate_results = true`.
"""
function prepare_simulation_data(problem, input, time_series_data, weather_selected_index)
    @unpack time_step = problem
    @unpack REGION, PERIOD, PLANT, no_regions, no_plants, no_periods = input
    @unpack simulated_cf, simulated_load, simulated_res_inflow, simulated_ror_inflow, simulated_PS_inflow = time_series_data
  
    load = AxisArray(zeros(no_regions, no_periods), REGION, PERIOD)
    res_inflow = AxisArray(zeros(no_regions, no_periods), REGION, PERIOD)
    ror_inflow = AxisArray(zeros(no_regions, no_periods), REGION, PERIOD)
    PS_inflow = AxisArray(zeros(no_regions, no_periods), REGION, PERIOD)
    cf = AxisArray(ones(no_regions, no_plants, no_periods), REGION, PLANT, PERIOD)
    
    cf[:, :Wind, :] = simulated_cf[weather_selected_index , :, :Wind, :]
    cf[:, :OffWind, :] = simulated_cf[weather_selected_index , :, :OffWind, :]
    cf[:, :PV, :] = simulated_cf[weather_selected_index, :, :PV, :]
    cf[:, :RooftopPV, :] = simulated_cf[weather_selected_index, :, :RooftopPV, :]
    load[:, :] = simulated_load[weather_selected_index, :, :]
    res_inflow[:, :] = simulated_res_inflow[weather_selected_index, :, :] 
    ror_inflow[:, :] = simulated_ror_inflow[weather_selected_index, :, :]
    PS_inflow[:, :] = simulated_PS_inflow[weather_selected_index, :, :] 

    return(; cf, load, res_inflow, ror_inflow, PS_inflow)
end

#//////////////////////////////////////////////////////////////////////////////////////////////////

"""
ReadTimeSeriesData(problem, input)

Read all time series files used by the model:
- load, hydro inflows, and PV/wind capacity factors
- Files are expected in `Time series sts/` and `Simulation data sts/`
Returns: SIMULATION_YEARS and arrays `simulated_cf`, `simulated_load`, `simulated_res_inflow`, `simulated_ror_inflow`, `simulated_PS_inflow`.
Note: years in `Simulation data sts` are mapped to `SIMULATION_YEARS` via `y + 1978`.
"""
function ReadTimeSeriesData(problem, input)
    @unpack REGION, PERIOD, PLANT, no_regions, no_periods, no_plants = input
    @unpack input_data_length, time_step, use_mean_aggregation = problem 
    println("\nReading time series Data...")
    folder = dirname(@__FILE__) # directory path containing the script
    SIMULATION_YEARS = 1:40   # corresponds to 1979-2018
    no_simulations=length(SIMULATION_YEARS)
    
    load_timeseries = CSV.read("$folder\\Time series sts\\Load_TimeSeries_sts_2022_2023.csv", DataFrame)
    res_inflow_timeseries = CSV.read("$folder\\Time series sts\\Res_inflow_TimeSeries_sts.csv", DataFrame)
    ror_inflow_timeseries = CSV.read("$folder\\Time series sts\\RoR_inflow_TimeSeries_sts.csv", DataFrame)
    PS_inflow_timeseries = CSV.read("$folder\\Time series sts\\PS_inflow_TimeSeries_sts.csv", DataFrame)

    simulated_load = AxisArray(zeros(no_simulations, no_regions, no_periods), SIMULATION_YEARS, REGION, PERIOD)
    simulated_res_inflow = AxisArray(zeros(no_simulations, no_regions, no_periods), SIMULATION_YEARS, REGION, PERIOD)
    simulated_ror_inflow = AxisArray(zeros(no_simulations, no_regions, no_periods), SIMULATION_YEARS, REGION, PERIOD)
    simulated_PS_inflow = AxisArray(zeros(no_simulations, no_regions, no_periods), SIMULATION_YEARS, REGION, PERIOD)
    simulated_cf = AxisArray(ones(no_simulations, no_regions, no_plants, no_periods), SIMULATION_YEARS, REGION, PLANT, PERIOD)

    # Create a dictionary to map each region to its corresponding x value
    region_to_x = Dict()
    for (index, r) in enumerate(REGION)
        region_to_x[r] = "x$index"
    end

    for y in SIMULATION_YEARS 
        windtimeseries = CSV.read("$folder\\Simulation data sts\\cfwind_sts_$(y+1978).csv", DataFrame)
        offwindtimeseries = CSV.read("$folder\\Simulation data sts\\cfoffwind_sts_$(y+1978).csv", DataFrame)
        solartimeseries = CSV.read("$folder\\Simulation data sts\\cfsolar_sts_$(y+1978).csv", DataFrame)
        rooftopPVtimeseries = CSV.read("$folder\\Simulation data sts\\cfroof_sts_$(y+1978).csv", DataFrame)

        if use_mean_aggregation # calculates the mean values over the time step 
            for h in PERIOD
            index = (h - 1) * time_step + 1 
            selected_range = index:index + time_step - 1
            for r in REGION
                x = region_to_x[r]  # Get the corresponding x value
                simulated_res_inflow[y, r, h] = sum(res_inflow_timeseries[selected_range, "HydroRes_inflow_" * string(r)])/ time_step  # [MWh]
                simulated_ror_inflow[y, r, h] = sum(ror_inflow_timeseries[selected_range, "HydroRoR_inflow_" * string(r)])/ time_step
                simulated_PS_inflow[y, r, h] = sum(PS_inflow_timeseries[selected_range, "HydroPS_inflow_" * string(r)])/ time_step
                simulated_load[y, r, h] = sum(load_timeseries[selected_range, "Load_" * string(r)])/ time_step  # [MWh]
                
                simulated_cf[y, r,:Wind, h] = sum(windtimeseries[selected_range, "$x"])/ time_step  # 0-1, share of installed cap
                simulated_cf[y, r,:OffWind, h] = sum(offwindtimeseries[selected_range, "$x"])/ time_step  
                simulated_cf[y, r,:PV, h] = sum(solartimeseries[selected_range, "$x"])/ time_step 
                simulated_cf[y, r,:RooftopPV, h] = sum(rooftopPVtimeseries[selected_range, "$x"])/ time_step  
            end
        end
        else # uses the values at the specific time step
            for h in PERIOD
                index = (h - 1) * time_step + 1 
                for r in REGION
                    x = region_to_x[r]
                    simulated_res_inflow[y, r, h] = res_inflow_timeseries[index, "HydroRes_inflow_" * string(r)]  # [MWh]
                    simulated_ror_inflow[y, r, h] = ror_inflow_timeseries[index, "HydroRoR_inflow_" * string(r)]
                    simulated_PS_inflow[y, r, h] = PS_inflow_timeseries[index, "HydroPS_inflow_" * string(r)]
                    simulated_load[y, r, h] = load_timeseries[index, "Load_" * string(r)]  # [MWh]
                    
                    simulated_cf[y, r,:Wind, h] = windtimeseries[index, "$x"]
                    simulated_cf[y, r,:OffWind, h] = offwindtimeseries[index, "$x"]
                    simulated_cf[y, r,:PV, h] = solartimeseries[index, "$x"]
                    simulated_cf[y, r,:RooftopPV, h] = rooftopPVtimeseries[index, "$x"]
                end
            end
        end
    end

    return(; SIMULATION_YEARS, simulated_cf, simulated_load, simulated_res_inflow, simulated_ror_inflow, simulated_PS_inflow)
end
