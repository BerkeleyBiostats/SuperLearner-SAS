# SuperLearner SAS macro

[SuperLearner-SAS](https://github.com/BerkeleyBiostats/SuperLearner-SAS) is a SAS implementation of the Super Learner algorithm, an ensemble learning algorithm, also referred to as Stacking. 

Author: Jordan Brooks


## Run the macro

The `./data` folder is where the simulated data is deposited as a permanent SAS dataset. For data analyses, this is were the data sample would be deposited prior to analysis. It is empty and could be deleted, but anyone actually using the SAS code would need to create it again. Alternatively, SAS can be coded to check for the directory and then create it if does not already exist but I have not implemented that.