# =================================================================================== #
#                    The effect on weather effects on inflation                       #
#                               Replication package                                   #
#                                                                                     #
#                                                                                     #
# Lenin Arango-Castillo (Bank of Mexico) [corresponding author]                       #
#  - contact: larangoc@banxico.org.mx                                                 #
# Francisco J. Martinez-Ramirez (Bank of Mexico)                                      #
#  - contact: franciscomr@banxico.org.mx                                              #
# =================================================================================== #


The project was written using the R programming language. The scripts that reproduce the whole project are stored in the `Code` directory. The script called `00_MASTER.R` runs sources all the projects scripts and thus processes and analyzes all data. 

The master script has a section called "Hyper-parameters". In this section the user defines modifications to perform to the analysis. The pre-defined hyperparameters are those used in the paper. There are three types of hyper-parameters to consider: i) those used in the data cleaning process, ii) those used in the econometric analysis, and iii) those used in all the project, which are:
	- Time period to analyze
	- Climate data base to use (CONAGUA/CRU)
	- Frequency of the data (Monthly/Quarterly)
	- Number of Mexican regions to consider (4/7)
	- Time series transformations (season adjust/centering/percentage variation)
	- Treshold to define (weighted) temperature and climate deviations



***************************************************************************************
                               DATA PREPARATION                 
***************************************************************************************

** Hyper-parameters in Master script used for this section:
	- The number of years to construct climate norms (if using **CONAGUA** data only 15 years are allowed).


** Climate data:

The temperature and precipitation data comes from two sources: 
	i) National  Water  Comission (CONAGUA) or 
       ii) Climate Unit Research of the University of East Anglia (CRU) through the World Bank. 

The main analysis is done with either the two sources of data. The data from CRU
covers from the year 1901 to 2024, while the CONAGUA data covers from 1985 to 2025.

There is a special directory to store the climate raw data files: `\Data\Raw.Data\Climate`.


** Price indices data:

The price indices used are components of the Consumer Price Indices which come from INEGI. The raw indices are stored in: `\Data\Raw.Data\Inflation`.


** Auxiliary data

Further, there is the directory `\Data\Raw.Data\Helpers`, which contains files with information regarding the region that the Mexican states and cities belong to. They are used to create mean (population-weighted) temperature and precipitation by region.


** Scripts to pre-process (clean) raw data files

The scripts are stored in the `Code` directory. The scripts are numbered. The files with the number 01 call the raw files and process them, while the file with the number 02 merge the processed climate and price indices data.  


** Scripts to merge pre-processed (cleaned) raw data files

The R srcipt `02_Merge_Economic-Climate-data_Regions.R` exports a csv file with the processed climate and economic data. This csv file is used to estimate Local Projections and the ARDL models. Provided that the R script accepts different parameters to construct the final data, separate files are exported according to the selected hyper-parameters. Thus, one can export different types of csvs to work on the main data analysis.


*** Main files to clean and process data
	- 01_Manage_Climate_Regions.R
	- 01_Manage_INPC_Regions.R
	- 02_Merge_Economic-Climate-data_Regions.R
 
Inside the `Code` directory there is a directory called `Functions`, which has the R scripts of some functions that will be useful in the data construction and analysis. They all start with the number 99.

The data set that will be used in the econometric analysis is exported to a csv file:
 - `/Data/{file name}.csv`



***************************************************************************************
                             ECONOMETRIC ANALYSIS
***************************************************************************************

The econometric analysis consists of 3 scripts. As a summary of the pipeline, the scripts will plot descriptive stats and maps, estimate local projections (LP), and fit panel autoregressive distributed lag models (panel ARDL). The scripts are in the same directory as those used to construct the main data, however, they are identified with the numbers 10-12.

As in the data construcution section, the econometric analysis scripts make use of functions defined by the project's authors. The functions are located in `/Code/Functions` and are identified with the number 99 at the beginning of the file name. The functions are called at the beginning of each 10-12 script.

The scripts automatically construct the `Results` and `Figures` directories (and its subdirectories) so the output is correctly stored. The directories are created in the directory used to run the project

*** Hyper-parameters in Master script used for this section:
	- Climate norm to use in the analysis (if using CONAGUA data only 15 years are allowed)
	- Horizon to consider for the Impulse-Response Function (IRF) estimation
	- The significance level of the IRF estimation (0.01, 0.05, 0.1)
	- Inflation variation to consider (monthly/quarterly/annualy)

*** Main files for the econometric analysis
	- 10_DescriptivePlots_Economic-Climate_Regions.R
	- 11_IRF-LP_Economic-Climate_Regions.R
	- 12_ARDL_Economic-Climate_Regions.R
