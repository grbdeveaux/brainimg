% Probably a good idea to add a feature where the user can cycle through
% blobs to select tumors!

% Maybe make it so the user can add their own parameters and the output
% changes on the fly!

clear all;
close all;

set(0, 'defaultTextInterpreter', 'tex');
set(groot, 'defaultAxesTickLabelInterpreter', 'tex');
set(groot, 'defaultLegendInterpreter', 'tex');


sliceLvl = 105;
skull_thresh = 40;
otsuScale = 1.05;

%% LOAD IMAGE

imageDir = '~/Documents/TrainingData/MICCAI_BraTS_2018_Data_Training/HGG/';
imgName = 'Brats18_CBICA_AAB_1';
modality = 'flair'
img = [imageDir imgName filesep imgName '_' modality '.nii'];

V = niftiread(img);
img = V(:,:,sliceLvl);
img = rescale(img, 0, 255)
img = uint8(img)

%% START
baseFileName = imgName
% Get the dimensions of the image.  
% Get the number of color channels in the image.
[rows, columns, numberOfColorChannels] = size(img)

%Convert image to grayscale
%img = rgb2gray(img);

% Display the image.
subplot(2, 3, 1);
imshow(uint8(img));
axis on;
title("Original Grayscale Image "+ baseFileName);
drawnow;

% Set up figure properties:
% Enlarge figure to full screen.
%set(gcf, 'Units', 'Normalized', 'OuterPosition', [0 0 1 1]);

% Get rid of tool bar and pulldown menus that are along top of figure.
set(gcf, 'Toolbar', 'none', 'Menu', 'none');

% Give a name to the title bar.
set(gcf, 'Name', 'The Braininator 6000', 'NumberTitle', 'Off') 

% Make the pixel info status line be at the top left of the figure.
hp.Units = 'Normalized';
hp.Position = [0.01, 0.97, 0.08, 0.05];

%%
% Display the histogram so we can see what gray level we need to threshold it at.
histimg = img(find(img>10));
[histmode, histmodefreq] = mode(histimg);

subplot(2, 3, 2:3);
imhist(histimg);
% For most MRI scans, there is a huge number of dark pixels. Ignore those
% with intensity less that 10 to avoid crowding the histogram.

title('Histogram of Non-Black Pixels');
ylabel('Pixel Counts');
ylim([0 histmodefreq+10])

%%
%{
% Threshold the image to make a binary image.
thresholdValue = 260;
binaryImage = img > thresholdValue;
%}
% Calculate the threshold and binarize the image (method taken from Lab 2)
% Here the threshold will likely have to be calculated in a smarter way. We
% need a good brain database to figure out how tumours usually show up.

fprintf("The skull threshold value for the image is "+ skull_thresh + "\n");
binaryImage = imbinarize(img, skull_thresh/255);

% Display the image.
subplot(2, 3, 4);
imshow(binaryImage, []);
axis on;
title("Initial binary image threshdolded at "+ skull_thresh);

%%
% Extract the outer blob, which is the skull.  
% The outermost blob will have a label number of 1.
% labeledImage = bwlabel(binaryImage);		% Assign label ID numbers to all blobs.
% binaryImage = ismember(labeledImage, 1);	% Use ismember() to extract blob #1.

binaryImage = bwareafilt(binaryImage, 1); % Extract largest blob.

% Display the final binary image.
subplot(2, 3, 5);
imshow(binaryImage, []);
axis on;
title('Final binary image of brain alone');

%%
% Mask out the skull from the original gray scale image.
skullFreeImage = img; % Initialize
skullFreeImage(~binaryImage) = 0; % Mask out.
% Display the image.
subplot(2, 3, 6);
imshow(skullFreeImage, []);
hp = impixelinfo(); % Add pixel information tool to the figure.
axis on;
title("Grayscale image of brain only");


%%
%{
% Give user a chance to see the results on this figure, then offer to continue and find the tumor.
promptMessage = sprintf('Do you want to continue and find the tumor,\nor Quit?');
titleBarCaption = 'Continue?';

buttonText = questdlg(promptMessage, titleBarCaption, 'Continue', 'Quit', 'Continue');
if strcmpi(buttonText, 'Quit')
	return;
end
%}

%%
% Now threshold to find the tumor

otsuImg= skullFreeImage(find(skullFreeImage>1));
otsuThresh = graythresh(otsuImg);
tumorThresh= otsuScale * otsuThresh

binaryImage = imbinarize(skullFreeImage, tumorThresh);

fprintf("The tumor threshold value for the image is "+ 255*tumorThresh+ "\n");

% Display the image.
hFig2 = figure();
subplot(2, 3, 1);
imshow(binaryImage, []);
axis on;
title("Initial binary image of tumor threshdolded at "+ 255*tumorThresh);

% Set up figure properties:
% Enlarge figure.
set(gcf, 'Units', 'Normalized', 'OuterPosition', [0.25 0.15 .5 0.7]);

%%
% Assume the tumor is the largest blob and extract it
binaryTumorImage = bwareafilt(binaryImage, 1);
% Display the image.
subplot(2, 3, 2);
imshow(binaryTumorImage, []);
axis on;
title('Tumor Alone');

%%
fprintf("For finding boundaries:\n");

% Find tumor boundaries.
% bwboundaries() returns a cell array, where each cell contains the row/column coordinates for an object in the image.
% Plot the borders of the tumor over the original grayscale image using the coordinates returned by bwboundaries.
subplot(2, 3, 3);
imshow(img, []);
axis on;
title("Tumor Outlined in red in the overlay"); 
axis image; % Make sure image is not artificially stretched because of screen's aspect ratio.
hold on;
tic;
boundaries = bwboundaries(binaryTumorImage); % This function is REALLY slow (2.5s)
toc;
numberOfBoundaries = size(boundaries, 1);
for k = 1 : numberOfBoundaries
	thisBoundary = boundaries{k};
	% Note: since array is row, column not x,y to get the x you need to use the second column of thisBoundary.
	plot(thisBoundary(:,2), thisBoundary(:,1), 'r', 'LineWidth', 2);
end
hold off;


%%
% Now indicate the tumor a different way, with a red tinted overlay instead of outlines.
subplot(2, 3, 4);
imshow(img, []);
title("Tumor Solid & tinted red in overlay"); 
axis image; % Make sure image is not artificially stretched because of screen's aspect ratio.
hold on;
% Display the tumor in the same axes.
% Make a truecolor all-red RGB image.  Red plane has the tumor and the green and blue planes are black.
segOverlay = cat(3, ones(size(binaryTumorImage)), zeros(size(binaryTumorImage)), zeros(size(binaryTumorImage)));
hRedImage = imshow(segOverlay); % Save the handle; we'll need it later.
axis on;
% Now the tumor image "covers up" the gray scale image.
% We need to set the transparency of the red overlay image to be 30% opaque (70% transparent).
alpha_data_red = 0.3 * double(binaryTumorImage);
set(hRedImage, 'AlphaData', alpha_data_red);


%%
% Now indicate the ground truth
subplot(2, 3, 5);
imshow(img, []);
title("Ground Truth overlayed on brain"); 
axis image; % Make sure image is not artificially stretched because of screen's aspect ratio.
hold on;

modality = 'seg'
groundTruth = [imageDir imgName filesep imgName '_' modality '.nii'];

groundTruth = niftiread(groundTruth);
groundTruth = groundTruth(:,:,sliceLvl);
groundTruth = rescale(groundTruth, 0, 255);
groundTruth = rescale(groundTruth);

% Display the tumor in the same axes.
% Make a truecolor all-blue RGB image.  Blue plane has the tumor.
truthOverlay = cat(3, zeros(size(groundTruth)), zeros(size(groundTruth)), groundTruth);
hBlueImage = imshow(truthOverlay); % Save the handle; we'll need it later.
axis on;
% Now the tumor image "covers up" the gray scale image.
% We need to set the transparency of the red overlay image to be 30% opaque (70% transparent).
alpha_data = 0.3 * double(groundTruth);
set(hBlueImage, 'AlphaData', alpha_data);
hold off;

%%
% Now indicate the ground truth
figure;
imshow(img, []);
title("Ground Truth overlayed on brain"); 
axis image; % Make sure image is not artificially stretched because of screen's aspect ratio.
hold on;

modality = 'seg'
groundTruth = [imageDir imgName filesep imgName '_' modality '.nii'];

groundTruth = niftiread(groundTruth);
groundTruth = groundTruth(:,:,sliceLvl);
groundTruth = rescale(groundTruth);
groundTruth = logical(groundTruth);

% Display the tumor in the same axes.
% Make a truecolor all-blue RGB image.  Blue plane has the tumor.
segOverlay = cat(3, ones(size(binaryTumorImage)), zeros(size(binaryTumorImage)), zeros(size(binaryTumorImage)));
hRedImage = imshow(segOverlay); % Save the handle; we'll need it later.
truthOverlay = cat(3, zeros(size(groundTruth)), zeros(size(groundTruth)), groundTruth);
hBlueImage = imshow(truthOverlay); % Save the handle; we'll need it later.
axis on;
% Now the tumor image "covers up" the gray scale image.
% We need to set the transparency of the red overlay image to be 30% opaque (70% transparent).
alpha_data_red = 0.3 * double(binaryTumorImage);
set(hRedImage, 'AlphaData', alpha_data_red);
alpha_data = 0.3 * double(groundTruth);
set(hBlueImage, 'AlphaData', alpha_data);
hold off;


%% Compare

groundTruthCard = sum(groundTruth(:));
binaryTumorImageCard = sum(binaryTumorImage(:));

goodGuess = groundTruth .* binaryTumorImage;
falseNeg = groundTruth - goodGuess;
falsePos = binaryTumorImage - goodGuess;

similarity = dice(groundTruth,binaryTumorImage)