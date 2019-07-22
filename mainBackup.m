%% Preamble
clear all;
close all;

set(0, 'defaultTextInterpreter', 'tex');
set(groot, 'defaultAxesTickLabelInterpreter', 'tex');
set(groot, 'defaultLegendInterpreter', 'tex');

%% Modifiable parameters

otsuScale = 1.1;
strelSize = 2;
growingFactor = 1.3;

%% Select and load image and corresponding ground truth
[imgFileName,imgDir] = uigetfile('*.nii');

imgpath = [imgDir imgFileName];
fullNifti = niftiread(imgpath);

segpath = strrep(imgpath,'flair','seg')
fullGround = logical(niftiread(segpath));

%% Find slice with biggest tumor value from groundTruth

[x,y,z,intensity] = size(fullGround)

for i = 1:z
    groundSlice = fullGround(:,:,i);
    A(i) = nnz(groundSlice);
end

[M,sliceLvl] = max(A)

groundTruth = fullGround(:,:,sliceLvl); % Truth at corresponding height
imgSlice = fullNifti(:,:,sliceLvl); % FLAIR at corresponding height

%% Equalize imgSlice to full uint16 range
maxvalue = 65535
imgSlice = rescale(imgSlice, 0, maxvalue);
imgSlice = uint16(imgSlice);

%% Keep only the brain, which is the largest blob
% The outermost blob will have a label number of 1.
% labeledImage = bwlabel(binaryImage);		% Assign label ID numbers to all blobs.
% binaryImage = ismember(labeledImage, 1);	% Use ismember() to extract blob #1.

otsuThresh = graythresh(imgSlice);
fprintf("Binarize threshhold value for the image is "+ otsuThresh/maxvalue + "\n");
binaryBrain = imbinarize(imgSlice, otsuThresh/maxvalue);
binaryBrain = bwareafilt(binaryBrain, 1); % Extract largest blob.

brainImage = imgSlice; % Initialize
brainImage(~binaryBrain) = 0; % only keep brain

%% Now threshold to find the tumor

otsuImg= brainImage(find(brainImage>1)); % Remove background pixels
otsuThresh = graythresh(otsuImg);
tumorThresh= otsuScale * otsuThresh

binaryBrain = imbinarize(brainImage, tumorThresh);

%% Dilate binarized prediction to connect neighbouring blobs

SE = strel('diamond',strelSize)

dilatedTumorBinary= imdilate(binaryBrain,SE);
biggestBlob = bwareafilt(dilatedTumorBinary, 1);

binaryTumorImage = biggestBlob .* binaryBrain;
binaryTumorImage = imfill( binaryTumorImage ,'holes')
prediction = logical(binaryTumorImage);

%% Region growing to select neighbouring bright areas

pred = prediction;

% Find centroid of prediction
center = regionprops(biggestBlob,'centroid');

centx = center.Centroid(1);
centy = center.Centroid(2);

pregrow = imgSlice + 60000.*uint16(pred);

postgrow = grayconnected(pregrow,uint8(centy),uint8(centx), uint16(growingFactor*maxvalue*tumorThresh)) 

prediction=postgrow;

%% Compare

goodGuess = double(groundTruth .* prediction);
falseNeg = double(groundTruth - goodGuess);
falsePos = double(prediction - goodGuess);

similarity = dice(groundTruth,prediction)

%% Prediction overlayed on original

addNum=0.2*maxvalue;
subNum=-0.2*maxvalue;

imgSlice = double(imgSlice);
R = imgSlice + addNum .* prediction;
G = imgSlice + subNum .* prediction;
B = imgSlice + subNum .* prediction;

predictionOverlayed = cat(3, R, G, B);

%% Ground truth overlayed on original

imgSlice = double(imgSlice);
R = imgSlice + subNum .* groundTruth;
G = imgSlice + subNum .* groundTruth;
B = imgSlice + addNum .* groundTruth;

truthOverlayed = cat(3, R, G, B);

%% Comparison image

imgSlice = double(imgSlice);
R = imgSlice + addNum .* falsePos + subNum .* goodGuess + subNum .* falseNeg;
G = imgSlice + subNum .* falsePos + addNum .* goodGuess + subNum .* falseNeg;
B = imgSlice + subNum .* falsePos + subNum .* goodGuess + addNum .* falseNeg;

compareImage = cat(3, R, G, B);

%% Write all the images

writePath = [pwd '/Results/' imgFileName 'Original.png'];
imwrite(uint16(imgSlice), writePath);

writePath = [pwd '/Results/' imgFileName 'Prediction.png'];
imwrite(uint16(predictionOverlayed), writePath);

writePath = [pwd '/Results/' imgFileName 'Ground Truth.png'];
imwrite(uint16(truthOverlayed), writePath);

writePath = [pwd '/Results/' imgFileName '.png'];
imwrite(uint16(compareImage), writePath);