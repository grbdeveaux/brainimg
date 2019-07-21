clear all;
close all;

set(0, 'defaultTextInterpreter', 'tex');
set(groot, 'defaultAxesTickLabelInterpreter', 'tex');
set(groot, 'defaultLegendInterpreter', 'tex');

sliceLvl = 105;
skull_thresh = 40;
otsuScale = 1.2;

[imgfilename,imgdir] = uigetfile('*.nii');

%% LOAD IMAGE

imgpath = [imgdir imgfilename];
fullNifti = niftiread(imgpath);

%% Find slice with biggest tumor value from groundTruth

segpath = strrep(imgpath,'flair','seg')

fullGround = niftiread(segpath);
fullGround = logical(fullGround);

[x,y,z,intensity] = size(fullGround)

for i = 1:z

    groundSlice = fullGround(:,:,i);
    A(i) = nnz(groundSlice);
        
end

[M,sliceLvl] = max(A)

groundTruth = fullGround(:,:,sliceLvl);
imgslice = fullNifti(:,:,sliceLvl);
ogimg = rescale(imgslice, 0, 255)
ogimg = uint8(ogimg)


%% START
baseFileName = imgfilename
% Get the dimensions of the image.  
% Get the number of color channels in the image.
[rows, columns, numberOfColorChannels] = size(ogimg)

%%
% Display the histogram so we can see what gray level we need to threshold it at.
histimg = ogimg(find(ogimg>10));
[histmode, histmodefreq] = mode(histimg);

%%
% Calculate the threshold and binarize the image (method taken from Lab 2)
% Here the threshold will likely have to be calculated in a smarter way. We
% need a good brain database to figure out how tumours usually show up.

fprintf("The skull threshold value for the image is "+ skull_thresh + "\n");
binaryImage = imbinarize(ogimg, skull_thresh/255);

%%
% Extract the outer blob, which is the skull.  
% The outermost blob will have a label number of 1.
% labeledImage = bwlabel(binaryImage);		% Assign label ID numbers to all blobs.
% binaryImage = ismember(labeledImage, 1);	% Use ismember() to extract blob #1.

binaryImage = bwareafilt(binaryImage, 1); % Extract largest blob.

%%
% Mask out the skull from the original gray scale image.
skullFreeImage = ogimg; % Initialize
skullFreeImage(~binaryImage) = 0; % Mask out.

%%
% Now threshold to find the tumor

otsuImg= skullFreeImage(find(skullFreeImage>1));
otsuThresh = graythresh(otsuImg);
tumorThresh= otsuScale * otsuThresh

binaryImage = imbinarize(skullFreeImage, tumorThresh);

fprintf("The tumor threshold value for the image is "+ 255*tumorThresh+ "\n");

%%
% Assume the tumor is the largest blob and extract it

SE = strel('octagon',3);
SE = [ 1 1; 1 1]

dilatedTumorBinary= imdilate(binaryImage,SE);

biggestBlob = bwareafilt(dilatedTumorBinary, 1);

binaryTumorImage = biggestBlob .* binaryImage;

binaryTumorImage = imfill( binaryTumorImage ,'holes')

binaryTumorImage = logical(binaryTumorImage);

%%

% Display the tumor in the same axes.
% Make a truecolor all-red RGB image.  Red plane has the tumor and the green and blue planes are black.
tumorOverlay = cat(3, ones(size(binaryTumorImage)), zeros(size(binaryTumorImage)), zeros(size(binaryTumorImage)));

% Now the tumor image "covers up" the gray scale image.
% We need to set the transparency of the red overlay image to be 30% opaque (70% transparent).
alpha_data_red = 0.3 * double(binaryTumorImage);


%%

groundTruth = fullGround(:,:,sliceLvl);
groundTruth = logical(groundTruth);

% Display the tumor in the same axes.
% Make a truecolor all-blue RGB image.  Blue plane has the tumor.
truthOverlay = cat(3, zeros(size(groundTruth)), zeros(size(groundTruth)), groundTruth);

% Now the tumor image "covers up" the gray scale image.
% We need to set the transparency of the red overlay image to be 30% opaque (70% transparent).
alpha_data_blue = 0.3 * double(groundTruth);

% N = nnz()

% Display the tumor in the same axes.
% Make a truecolor all-blue RGB image.  Blue plane has the tumor.
tumorOverlay = cat(3, ones(size(binaryTumorImage)), zeros(size(binaryTumorImage)), zeros(size(binaryTumorImage)));
truthOverlay = cat(3, zeros(size(groundTruth)), zeros(size(groundTruth)), groundTruth);

%% Compare

groundTruthCard = sum(groundTruth(:));
binaryTumorImageCard = sum(binaryTumorImage(:));

goodGuess = groundTruth .* binaryTumorImage;
falseNeg = groundTruth - goodGuess;
falsePos = binaryTumorImage - goodGuess;

similarity = dice(groundTruth,binaryTumorImage)

%% Display all the images

% Display the original image.
figure;
subplot(2, 3, 1);
imshow(uint8(ogimg));
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

subplot(2, 3, 2:3);
imhist(histimg);

% For most MRI scans, there is a huge number of dark pixels. Ignore those
% with intensity less that 10 to avoid crowding the histogram.

title('Histogram of Non-Black Pixels');
ylabel('Pixel Counts');
ylim([0 histmodefreq+10])

% Display the image.
subplot(2, 3, 4);
imshow(binaryImage, []);
axis on;
title("Initial binary image threshdolded at "+ skull_thresh);

% Display the final binary image.
subplot(2, 3, 5);
imshow(binaryImage, []);
axis on;
title('Final binary image of brain alone');

% Display the image.
subplot(2, 3, 6);
imshow(skullFreeImage, []);
hp = impixelinfo(); % Add pixel information tool to the figure.
axis on;
title("Grayscale image of brain only");

% Display the image.
figure;
subplot(2, 3, 1);
imshow(binaryImage, []);
axis on;
title("Initial binary image of tumor threshdolded at "+ 255*tumorThresh);

% Set up figure properties:
% Enlarge figure.
set(gcf, 'Units', 'Normalized', 'OuterPosition', [0.25 0.15 .5 0.7]);

% Display the image.
subplot(2, 3, 2);
imshow(binaryTumorImage, []);
axis on;
title('Tumor Alone');

% Find tumor boundaries.
% bwboundaries() returns a cell array, where each cell contains the row/column coordinates for an object in the image.
% Plot the borders of the tumor over the original grayscale image using the coordinates returned by bwboundaries.
subplot(2, 3, 3);
imshow(ogimg, []);
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

% Now indicate the tumor a different way, with a red tinted overlay instead of outlines.
subplot(2, 3, 4);
imshow(ogimg, []);
title("Tumor Solid & tinted red in overlay"); 
axis image; % Make sure image is not artificially stretched because of screen's aspect ratio.
hold on;
hRedImage = imshow(tumorOverlay); % Save the handle; we'll need it later.
axis on;
set(hRedImage, 'AlphaData', alpha_data_red);

% Now indicate the ground truth
subplot(2, 3, 5);
imshow(ogimg, []);
title("Ground Truth overlayed on brain"); 
axis image; % Make sure image is not artificially stretched because of screen's aspect ratio.
hold on;
hBlueImage = imshow(truthOverlay); % Save the handle; we'll need it later.
axis on;
set(hBlueImage, 'AlphaData', alpha_data_blue);
hold off;

% Display comparison
subplot(2, 3, 6);
imshow(ogimg, []);
title("Ground Truth overlayed on brain"); 
axis image; % Make sure image is not artificially stretched because of screen's aspect ratio.
hold on;

hRedImage = imshow(tumorOverlay); % Save the handle; we'll need it later.
hBlueImage = imshow(truthOverlay); % Save the handle; we'll need it later.
axis on;

% Now the tumor image "covers up" the gray scale image.
% We need to set the transparency of the red overlay image to be 30% opaque (70% transparent).
set(hRedImage, 'AlphaData', alpha_data_red);
set(hBlueImage, 'AlphaData', alpha_data_blue);
hold off;

groundTruthCard = sum(groundTruth(:));
binaryTumorImageCard = sum(binaryTumorImage(:));

goodGuess = double(groundTruth) .* double(binaryTumorImage);
falseNeg = double(groundTruth) - goodGuess
falsePos = double(binaryTumorImage) - goodGuess;

addNum=60
subNum=-80

ogimg = double(ogimg)

R = ogimg + addNum .* falsePos + subNum .* goodGuess + subNum .* falseNeg

G = ogimg + subNum .* falsePos + addNum .* goodGuess + subNum .* falseNeg

B = ogimg + subNum .* falsePos + subNum .* goodGuess + addNum .* falseNeg

compareImage = cat(3, R, G, B)

compareimg = uint8(compareImage)

imshow(compareimg)
