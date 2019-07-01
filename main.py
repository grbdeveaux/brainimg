# https://stackoverflow.com/questions/49834264/mri-brain-tumor-image-processing-and-segmentation-skull-removing

import numpy as np
import cv2
import scipy.io

from matplotlib import pyplot as plt
from skimage.morphology import extrema
from skimage.morphology import watershed as skwater

def ShowImage(title,img,ctype):
    plt.figure(figsize=(10, 10))
    if ctype=='bgr':
        b,g,r = cv2.split(img)       # get b,g,r
        rgb_img = cv2.merge([r,g,b])     # switch it to rgb
        plt.imshow(rgb_img)
    elif ctype=='hsv':
        rgb = cv2.cvtColor(img,cv2.COLOR_HSV2RGB)
        plt.imshow(rgb)
    elif ctype=='gray':
        plt.imshow(img,cmap='gray')
    elif ctype=='rgb':
        plt.imshow(img)
    else:
        raise Exception("Unknown colour type")
    plt.axis('off')
    plt.title(title)
    plt.show()

# Read in image
img = cv2.imread('./scans/brain1.png')
gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
#ShowImage('Brain with Skull', gray, 'gray')

#Make a histogram of the intensities in the grayscale image
plt.hist(gray.ravel(),256)
#plt.show()

#Threshold the image to binary using Otsu's method
ret, thresh = cv2.threshold(gray,0,255,cv2.THRESH_OTSU)
#ShowImage('Applying Otsu',thresh,'gray')

colormask = np.zeros(img.shape, dtype=np.uint8)
colormask[thresh!=0] = np.array((0,0,255))
blended = cv2.addWeighted(img,0.7,colormask,0.1,0)
#ShowImage('Blended', blended, 'bgr')

ret, markers = cv2.connectedComponents(thresh)

#Get the area taken by each component. Ignore label 0 since this is the background.
marker_area = [np.sum(markers==m) for m in range(np.max(markers)) if m!=0]
#Get label of largest component by area
largest_component = np.argmax(marker_area)+1 #Add 1 since we dropped zero above
#Get pixels which correspond to the brain
brain_mask = markers==largest_component

brain_mask = np.uint8(brain_mask)
kernel = np.ones((8,8),np.uint8)
closing = cv2.morphologyEx(brain_mask, cv2.MORPH_CLOSE, kernel)
#ShowImage('Closing', closing, 'gray')

brain_out = img.copy()
#In a copy of the original image, clear those pixels that don't correspond to the brain
brain_out[closing==False] = (0,0,0)
#ShowImage('Connected Components222',brain_out,'rgb')









# https://docs.opencv.org/3.3.1/d3/db4/tutorial_py_watershed.html
# Watershed isn't working super well... I think thresholding and only keeping higher values would help.
# The separations here are not obvious. We need to really remove anything darker than 200

gray = cv2.cvtColor(brain_out,cv2.COLOR_BGR2GRAY)
ret, thresh = cv2.threshold(gray,0,255,cv2.THRESH_BINARY_INV+cv2.THRESH_OTSU)

equ = cv2.equalizeHist(gray)
ret = np.hstack((gray,equ)) #stacking images side-by-side
cv2.imwrite('res.png',ret)

# https://docs.opencv.org/3.4.3/d7/d4d/tutorial_py_thresholding.html

ret,img = cv2.threshold(img,160,255,cv2.THRESH_BINARY)

cv2.imwrite('Pre Erosion.png',img)

kernel = np.ones((5,5),np.uint8)
erosion = cv2.erode(img,kernel,iterations = 1)

cv2.imwrite('Post Erosion.png',erosion)

# How do we remove the bright spots that aren't tumours?
# Maybe this is just a bad image and the real images won't have any big bright spots other than the tumour.
# Then we can do opening and dilation and all that's gonna be left is the tumour.
# Good approach from here might be to remove everything that's ~200 brightness or lower...
# Then open, then dilate, then label
# At this point we should probably be able to segment a few things.





# noise removal
kernel = np.ones((3,3),np.uint8)
opening = cv2.morphologyEx(thresh,cv2.MORPH_OPEN,kernel, iterations = 2)
# sure background area
sure_bg = cv2.dilate(opening,kernel,iterations=3)
# Finding sure foreground area
dist_transform = cv2.distanceTransform(opening,cv2.DIST_L2,5)
ret, sure_fg = cv2.threshold(dist_transform,0.7*dist_transform.max(),255,0)
# Finding unknown region
sure_fg = np.uint8(sure_fg)
unknown = cv2.subtract(sure_bg,sure_fg)

# Marker labelling
ret, markers = cv2.connectedComponents(sure_fg)
# Add one to all labels so that sure background is not 0, but 1
markers = markers+1
# Now, mark the region of unknown with zero
markers[unknown==255] = 0

markers = cv2.watershed(img,markers)
img[markers == -1] = [255,0,0]