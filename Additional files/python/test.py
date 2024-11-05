import numpy as np
import struct as struct
import matplotlib.pyplot as plt

IMAGE_SIZE = 256

# Read corrupted image from SW file

swIm = plt.imread('lenaCorrupted.bmp')

plt.imshow(swIm, cmap='gray', vmin=0, vmax=255)
plt.title("SW original image")
plt.show()

# Histogram equalization
# Calculate histogram
pixVals = np.arange(0, 256)
h = np.zeros(256)

for r in range(swIm.shape[0]):
    for c in range(swIm.shape[1]):
        h[swIm[r][c]] += 1

# Calculate cumulative histogram and an equalization map
ch = np.zeros(len(h))
for p in range(len(h)):
    ch[p] = np.sum(h[0:p])

cdf = ch/(swIm.shape[0]*swIm.shape[1]/256)

# Equalize

swImE = np.zeros([IMAGE_SIZE, IMAGE_SIZE])

for r in range(swImE.shape[0]):
    for c in range(swImE.shape[1]):
        swImE[r][c] = cdf[swIm[r][c]]

plt.imshow(swImE, cmap='gray', vmin=0, vmax=255)
plt.title("SW equalized image")
plt.show()

#....................................................

swIm = swImE.astype(int)

plt.imshow(swIm, cmap='gray', vmin=0, vmax=255)
plt.title("SW original image")
plt.show()

# Histogram equalization
# Calculate histogram
pixVals = np.arange(0, 256)
h = np.zeros(256)

for r in range(swIm.shape[0]):
    for c in range(swIm.shape[1]):
        h[swIm[r][c]] += 1

# Calculate cumulative histogram and an equalization map
ch = np.zeros(len(h))
for p in range(len(h)):
    ch[p] = np.sum(h[0:p])

cdf = ch/(swIm.shape[0]*swIm.shape[1]/256)

# Equalize

swImE = np.zeros([IMAGE_SIZE, IMAGE_SIZE])

for r in range(swImE.shape[0]):
    for c in range(swImE.shape[1]):
        swImE[r][c] = cdf[swIm[r][c]]

plt.imshow(swImE, cmap='gray', vmin=0, vmax=255)
plt.title("SW equalized image 2")
plt.show()

#.................................................

swIm = swImE.astype(int)

plt.imshow(swIm, cmap='gray', vmin=0, vmax=255)
plt.title("SW original image")
plt.show()

# Histogram equalization
# Calculate histogram
pixVals = np.arange(0, 256)
h = np.zeros(256)

for r in range(swIm.shape[0]):
    for c in range(swIm.shape[1]):
        h[swIm[r][c]] += 1

# Calculate cumulative histogram and an equalization map
ch = np.zeros(len(h))
for p in range(len(h)):
    ch[p] = np.sum(h[0:p])

cdf = ch/(swIm.shape[0]*swIm.shape[1]/256)

# Equalize

swImE = np.zeros([IMAGE_SIZE, IMAGE_SIZE])

for r in range(swImE.shape[0]):
    for c in range(swImE.shape[1]):
        swImE[r][c] = cdf[swIm[r][c]]

plt.imshow(swImE, cmap='gray', vmin=0, vmax=255)
plt.title("SW equalized image 3")
plt.show()

swImE = swImE - swIm