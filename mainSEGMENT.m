%% Download Pretrained Network and Sample Test Set

trained3DUnet_url = 'https://www.mathworks.com/supportfiles/vision/data/brainTumor3DUNet.mat';
sampleData_url = 'https://www.mathworks.com/supportfiles/vision/data/sampleBraTSTestSet.tar.gz';

imageDir = fullfile(tempdir,'BraTS');
if ~exist(imageDir,'dir')
    mkdir(imageDir);
end
downloadTrained3DUnetSampleData(trained3DUnet_url,sampleData_url,imageDir);


%% Train the Network

doTraining = false;
if doTraining
    modelDateTime = datestr(now,'dd-mmm-yyyy-HH-MM-SS');
    [net,info] = trainNetwork(dsTrain,lgraph,options);
    save(['trained3DUNet-' modelDateTime '-Epoch-' num2str(maxEpochs) '.mat'],'net');
else
    load(fullfile(imageDir,'trained3DUNet','brainTumor3DUNet.mat'));
end

%% Perform Segmentation of Test Data

useFullTestSet = false;
if useFullTestSet
    volLocTest = fullfile(preprocessDataLoc,'imagesTest');
    lblLocTest = fullfile(preprocessDataLoc,'labelsTest');
else
    volLocTest = fullfile(imageDir,'sampleBraTSTestSet','imagesTest');
    lblLocTest = fullfile(imageDir,'sampleBraTSTestSet','labelsTest');
    classNames = ["background","tumor"];
    pixelLabelID = [0 1];
end

windowSize = [128 128 128];
volReader = @(x) centerCropMatReader(x,windowSize);
labelReader = @(x) centerCropMatReader(x,windowSize);
voldsTest = imageDatastore(volLocTest, ...
    'FileExtensions','.mat','ReadFcn',volReader);
pxdsTest = pixelLabelDatastore(lblLocTest,classNames,pixelLabelID, ...
    'FileExtensions','.mat','ReadFcn',labelReader);

id=1;
while hasdata(voldsTest)
    disp(['Processing test volume ' num2str(id)])
    
    groundTruthLabels{id} = read(pxdsTest);
    
    vol{id} = read(voldsTest);
    tempSeg = semanticseg(vol{id},net);

    % Get the non-brain region mask from the test image.
    volMask = vol{id}(:,:,:,1)==0;
    % Set the non-brain region of the predicted label as background.
    tempSeg(volMask) = classNames(1);
    % Perform median filtering on the predicted label.
    tempSeg = medfilt3(uint8(tempSeg)-1);
    % Cast the filtered label to categorial.
    tempSeg = categorical(tempSeg,pixelLabelID,classNames);
    predictedLabels{id} = tempSeg;
    id=id+1;
end