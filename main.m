% Probably a good idea to add a feature where the user can cycle through
% blobs to select tumors!

% Maybe make it so the user can add their own parameters and the output
% changes on the fly!

clear all;
close all;

set(0, 'defaultTextInterpreter', 'tex');
set(groot, 'defaultAxesTickLabelInterpreter', 'tex');
set(groot, 'defaultLegendInterpreter', 'tex');

%%
% SET IMPORTANT PARAMETERS
tumor_thresh = 140; % NEED A BETTER WAY OF FINDING TUMOR


%%
% Get the name of the image the user wants to use.
% baseFileName = 'skull_stripping_demo_image.dcm';
baseFileName = 'brain1.png';
% Get the full filename, with path prepended.
folder = pwd;
fullFileName = fullfile(folder, baseFileName);

% Check if exists in specified location.
if ~exist(fullFileName, 'file')
	% Check if file exists in current directory.
	if ~exist(baseFileName, 'file')
		% Still not found, tell user and close program.
		errorMessage = sprintf('Error: %s does not exist in the search path folders.', fullFileName);
		uiwait(warndlg(errorMessage));
		return;
	end
end

%%
% Read in image
img = imread(fullFileName);
% Get the dimensions of the image.  
% Get the number of color channels in the image.
[rows, columns, numberOfColorChannels] = size(img)

%Convert image to grayscale
img = rgb2gray(img);

% Display the image.
subplot(2, 3, 1);
imshow(uint8(img));
axis on;
title("Original Grayscale Image "+ baseFileName);
drawnow;

% Set up figure properties:
% Enlarge figure to full screen.
set(gcf, 'Units', 'Normalized', 'OuterPosition', [0 0 1 1]);
% Get rid of tool bar and pulldown menus that are along top of figure.
set(gcf, 'Toolbar', 'none', 'Menu', 'none');
% Give a name to the title bar.
set(gcf, 'Name', 'The Braininator 6000', 'NumberTitle', 'Off') 

% Make the pixel info status line be at the top left of the figure.
hp.Units = 'Normalized';
hp.Position = [0.01, 0.97, 0.08, 0.05];

%%
% Display the histogram so we can see what gray level we need to threshold it at.
subplot(2, 3, 2:3);
imhist(img);
% For most MRI scans, there is a huge number of dark pixels. Ignore those
% with intensity less that 10 to avoid crowding the histogram.

title('Histogram of Non-Black Pixels');
ylabel('Pixel Counts');

%%
%{
% Threshold the image to make a binary image.
thresholdValue = 260;
binaryImage = img > thresholdValue;
%}
% Calculate the threshold and binarize the image (method taken from Lab 2)
% Here the threshold will likely have to be calculated in a smarter way. We
% need a good brain database to figure out how tumours usually show up.

% thresh = threshold_value(img);
skull_thresh = 40;

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
% Give user a chance to see the results on this figure, then offer to continue and find the tumor.
promptMessage = sprintf('Do you want to continue and find the tumor,\nor Quit?');
titleBarCaption = 'Continue?';

buttonText = questdlg(promptMessage, titleBarCaption, 'Continue', 'Quit', 'Continue');
if strcmpi(buttonText, 'Quit')
	return;
end

%%
% Now threshold to find the tumor

% SHOULD FIND FUNCTION HERE TO GIVE RIGHT THRESHOLD. MAYBE TAKE ENTROPY
% INTO ACCOUNT. NEED BETTER WAY OF ISOLATING TUMOR

%binaryImage = skullFreeImage > tumor_thresh;
%binaryImage = imbinarize(skullFreeImage, 'adaptive');
binaryImage = imbinarize(skullFreeImage, tumor_thresh/255);

fprintf("The tumor threshold value for the image is "+ tumor_thresh+ "\n");

% Display the image.
hFig2 = figure();
subplot(2, 2, 1);
imshow(binaryImage, []);
axis on;
title("Initial binary image of tumor threshdolded at "+ tumor_thresh);

% Set up figure properties:
% Enlarge figure.
set(gcf, 'Units', 'Normalized', 'OuterPosition', [0.25 0.15 .5 0.7]);

%%
% Assume the tumor is the largest blob and extract it
binaryTumorImage = bwareafilt(binaryImage, 1);
% Display the image.
subplot(2, 2, 2);
imshow(binaryTumorImage, []);
axis on;
title('Tumor Alone');

%%
fprintf("For finding boundaries:\n");

% Find tumor boundaries.
% bwboundaries() returns a cell array, where each cell contains the row/column coordinates for an object in the image.
% Plot the borders of the tumor over the original grayscale image using the coordinates returned by bwboundaries.
subplot(2, 2, 3);
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
fprintf("For plotting red overlay:\n");
tic;
% Now indicate the tumor a different way, with a red tinted overlay instead of outlines.
subplot(2, 2, 4);
imshow(img, []);
title("Tumor Solid & tinted red in overlay"); 
axis image; % Make sure image is not artificially stretched because of screen's aspect ratio.
hold on;
% Display the tumor in the same axes.
% Make a truecolor all-red RGB image.  Red plane has the tumor and the green and blue planes are black.
redOverlay = cat(3, ones(size(binaryTumorImage)), zeros(size(binaryTumorImage)), zeros(size(binaryTumorImage)));
hRedImage = imshow(redOverlay); % Save the handle; we'll need it later.
hold off;
axis on;
% Now the tumor image "covers up" the gray scale image.
% We need to set the transparency of the red overlay image to be 30% opaque (70% transparent).
alpha_data = 0.3 * double(binaryTumorImage);
set(hRedImage, 'AlphaData', alpha_data);
toc;

%%
% FUNCTIONS TAKEN FROM LAB 2 TO CREATE BW IMAGE
% 1. Using the equations 1 and 2 develop a code to calculate the threshold value for any given image.

function threshold = threshold_value(img)

    [rownum, colnum] = size(img);
    [pixnum, val] = imhist(img);
    prob = pixnum(:) ./ (rownum * colnum);

    L = 255;

    variance = zeros(L - 1, 1);

    for t = 1:L - 1
        w0 = 0;
        w1 = 0;
        u0 = 0;
        u1 = 0;

        for i = 0 : t - 1
            w0 = w0 + prob(i + 1);
        end

        for i = t : L - 1
            w1 = w1 + prob(i + 1);
        end

        for i = 0 : t - 1
            u0 = u0 + i * prob(i + 1) / w0;
        end

        for i = t : L - 1
            u1 = u1 + i * prob(i + 1) / w1;
        end

        variance(t) = sqrt(w0 * w1 * (u1 - u0)^2);
    
    end

    [MaxVar, threshold] = max(variance);

end

% 4. Develop a code to convert a grayscale image to a binary image using a given threshold value. Do NOT use MATLAB function im2bw.
function binary_img = binarize(img, threshold)
    [imgrows, imgcols] = size(img);
    binary_img = zeros(imgrows, imgcols);

    for y = 1:imgrows

        for x = 1:imgcols

            if img(y, x) >= threshold
                binary_img(y, x) = 1;
            else
                binary_img(y, x) = 0;
            end

        end

    end

    binary_img = logical(binary_img);
end
