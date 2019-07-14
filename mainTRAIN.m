imageDir = '~/Documents/TrainingData/Task01_BrainTumour/'

%% Preprocess Training and Validation Data

sourceDataLoc = [imageDir 'Task01_BrainTumour'];
preprocessDataLoc = [imageDir 'preprocessedDataset'];
preprocessBraTSdataset(preprocessDataLoc,sourceDataLoc);

%% Create Random Patch Extraction Datastore for Training and Validation

