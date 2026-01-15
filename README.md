# Structural Overview

This project is an Electricity System Optimization Model written in Julia. Its primary purpose is to determine the optimal investment and dispatch of electricity generation, storage, and transmission capacities to meet demand at the lowest possible cost, given a set of technical and physical constraints.

The model is structured into four main files, each with a distinct role:

* **Input.jl**: *Data Loading and Pre-processing.*
  
  This file is responsible for reading all the necessary input data from CSV and Excel files, such as generator costs, renewable energy availability, electricity demand, and transmission grid characteristics. It then processes and organizes this data into data structures that the main model can use.

* **ElectricitySystemModel.jl**: *Core Model Definition.*
  
  This is the heart of the project. It uses the JuMP optimization modeling language to define the mathematical model, including decision variables (e.g., generator capacity, power dispatch), constraints (e.g., meeting demand, generation limits), and the objective function (minimizing total system cost).

* **Helpfunctions.jl**: *Utility and Post-processing.*
    
  This file contains helper functions for tasks like saving results to files, performing calculations, and plotting outputs. These functions are used across the other files to avoid code repetition and keep the main files cleaner.

* **Solve.jl**: *Execution and Orchestration.*
    
  This is the main script that you run. It orchestrates the entire process: it includes the other three files, calls the read_input function to get the data, passes that data to the run_model function to define and solve the optimization problem, and finally uses functions from Helpfunctions.jl to process and save the results.

**Typical Workflow:**  
Solve.jl -> Input.jl (reads data) -> ElectricitySystemModel.jl (builds and solves the model) -> Helpfunctions.jl (saves results).

*(For more information about each function, check the comments in the code.)*

---

## How to Use the Code

To run the model, you will primarily interact with the Solve.jl file. Here is a step-by-step guide:

### 1. Set Up Your Environment
* **Install Julia:** [https://julialang.org/downloads/](https://julialang.org/downloads/)
* **Install VSCode:** [https://code.visualstudio.com/](https://code.visualstudio.com/)
* **Install the Julia extension on VSCode**
* **Gurobi Optimizer:** [https://support.gurobi.com/hc/en-us/articles/14799677517585-Getting-Started-with-Gurobi-Optimizer](https://support.gurobi.com/hc/en-us/articles/14799677517585-Getting-Started-with-Gurobi-Optimizer)
    * Create a Gurobi account (use your University email)
    * Obtain Gurobi licence (Named-User Academic)
    * Install Gurobi
* **Install Julia packages:**
    *  Enter the Julia REPL (type “ julia ” in your terminal).
    *  Press “ ] ” to enter Pkg mode.
    * Copy and paste the following to install the Julia packages needed:  
        `add JuMP AxisArrays Gurobi UnPack StatsPlots Colors Statistics CSV DataFrames Plots PrettyTables NamedArrays Random Printf Crayons`

### 2. Configure a Simulation in Solve.jl
  *  Open the Solve.jl file in a text editor (VS Code).
  *  To open the code folder, if not already selected, navigate to "File" and select "Open folder...".  
    Then, choose **"EU_ Stochastic_Model"** and click "Select folder." (Make sure this folder is selected every time you run the code!)
  *  Configure the model by modifying the relevant parameters in function `main()`

      * **If deterministic optimization:**
          * `stochastic_model_scenarios = [<year>]`
          * `scenario_probability = [1]`

      * **If stochastic optimization:**
          * `stochastic_model_scenarios = [<year1>, <year2>, ...]`
          * `scenario_probability = [<prob1>, <prob2>, ...]` (prob. will be normalized)

### 3. Run the Simulation
Execute the Solve.jl script.

### 4. Find the Results
Once the model finishes solving, the results will be saved in the project directory as an HTML file.
