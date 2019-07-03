# https://stackoverflow.com/questions/49834264/mri-brain-tumor-image-processing-and-segmentation-skull-removing

import numpy as np
import cv2 as cv
import scipy.io

from PIL import Image, ImageStat

from matplotlib import pyplot as plt
from skimage.morphology import extrema
from skimage.morphology import watershed as skwater

def ShowImage(title,img,ctype):
    plt.figure(figsize=(10, 10))
    if ctype=='bgr':
        b,g,r = cv.split(img)       # get b,g,r
        rgb_img = cv.merge([r,g,b])     # switch it to rgb
        plt.imshow(rgb_img)
    elif ctype=='hsv':
        rgb = cv.cvtColor(img,cv.COLOR_HSV2RGB)
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
og = cv.imread('./scans/brain1.png')
img = og
gray = cv.cvtColor(img, cv.COLOR_BGR2GRAY)
#ShowImage('Brain with Skull', gray, 'gray')

#Make a histogram of the intensities in the grayscale image
plt.hist(gray.ravel(),256)
#plt.show()

#Threshold the image to binary using Otsu's method
ret, thresh = cv.threshold(gray,0,255,cv.THRESH_OTSU)
#ShowImage('Applying Otsu',thresh,'gray')

colormask = np.zeros(img.shape, dtype=np.uint8)
colormask[thresh!=0] = np.array((0,0,255))
blended = cv.addWeighted(img,0.7,colormask,0.1,0)
#ShowImage('Blended', blended, 'bgr')

ret, markers = cv.connectedComponents(thresh)

#Get the area taken by each component. Ignore label 0 since this is the background.
marker_area = [np.sum(markers==m) for m in range(np.max(markers)) if m!=0]
#Get label of largest component by area
largest_component = np.argmax(marker_area)+1 #Add 1 since we dropped zero above
#Get pixels which correspond to the brain
brain_mask = markers==largest_component

brain_mask = np.uint8(brain_mask)
kernel = np.ones((8,8),np.uint8)
closing = cv.morphologyEx(brain_mask, cv.MORPH_CLOSE, kernel)
#ShowImage('Closing', closing, 'gray')

brain_out = img.copy()
#In a copy of the original image, clear those pixels that don't correspond to the brain
brain_out[closing==False] = (0,0,0)
#ShowImage('Skull Removal',brain_out,'gray')




# https://stackoverflow.com/questions/3490727/what-are-some-methods-to-analyze-image-brightness-using-python

#avgbrightness = brightness('res.png')

a=brain_out
avgb = a[np.nonzero(a)].mean()

print(avgb)




# https://docs.opencv.org/3.3.1/d3/db4/tutorial_py_watershed.html
# Watershed isn't working super well... I think thresholding and only keeping higher values would help.
# The separations here are not obvious. We need to really remove anything darker than 200

gray = cv.cvtColor(brain_out,cv.COLOR_BGR2GRAY)
ret, thresh = cv.threshold(gray,0,255,cv.THRESH_BINARY_INV+cv.THRESH_OTSU)

equ = cv.equalizeHist(gray)
ret = np.hstack((gray,equ)) #stacking images side-by-side
cv.imwrite('res.png',ret)

#ShowImage('Skull Removal',ret,'rgb')

# https://docs.opencv.org/3.4.3/d7/d4d/tutorial_py_thresholding.html

ret,img = cv.threshold(img,1.15*avgb,255,cv.THRESH_BINARY)

cv.imwrite('Pre Erosion.png',img)

kernel = np.ones((5,5),np.uint8)

#img = cv.morphologyEx(img, cv.MORPH_OPEN, kernel)
#cv.imwrite('Post Opening.png',img)
img = cv.erode(img,kernel,iterations = 3)
cv.imwrite('Post Erosion1.png',img)
img = cv.dilate(img,kernel,iterations = 4)
cv.imwrite('Post Dilation1.png',img)


#https://answers.opencv.org/question/97416/replace-a-range-of-colors-with-a-specific-color-in-python/
img[np.where((img==[255,255,255]).all(axis=2))] = [0,0,255]
cv.imwrite('whatsthis.png',img)

# https://docs.opencv.org/3.4/d5/dc4/tutorial_adding_images.html

alpha = 0.5
try:
    raw_input          # Python 2
except NameError:
    raw_input = input  # Python 3


#print(''' Simple Linear Blender
#-----------------------
#* Enter alpha [0.0-1.0]: ''')
#input_alpha = float(raw_input().strip())
input_alpha = 0.5
if 0 <= alpha <= 1:
    alpha = input_alpha
# [load]
src1 = og
src2 = img
# [load]
if src1 is None:
    print("Error loading src1")
    exit(-1)
elif src2 is None:
    print("Error loading src2")
    exit(-1)
# [blend_images]
beta = (1.0 - alpha)
dst = cv.addWeighted(src1, alpha, src2, beta, 0.0)
cv.imwrite('Blendaroony1.png',dst)
# [blend_images]
# [display]
cv.imshow('dst', dst)
cv.waitKey(0)
# [display]
cv.destroyAllWindows()

# How do we remove the bright spots that aren't tumours?
# Maybe this is just a bad image and the real images won't have any big bright spots other than the tumour.
# Then we can do opening and dilation and all that's gonna be left is the tumour.
# Good approach from here might be to remove everything that's ~200 brightness or lower...
# Then open, then dilate, then label
# At this point we should probably be able to segment a few things.