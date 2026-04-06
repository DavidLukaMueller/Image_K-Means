# --- Load Libraries --- #
library("data.table")
library("plotly")
library("cluster")      # additional clustering algorithms
library("factoextra")   # A lot of nice visualizations and eval for clustering
library("corrplot")
library("ggplot2")
library("GGally")
library("imager")       # For image processing
library("animation")    # Visualizing multiple steps of the algorithm

# --- 1. Load and Inspect Image --- #
img <- imager::load.image("Assignment_Image.jpg")
plot(img)
str(img)

# --- 2. Resize to 256x256 --- #
img_resized <- imager::resize(img, size_x = 256, size_y = 256)
plot(img_resized)
str(img_resized)


# --- 3. Preprocessing --- #
dt_img <- as.data.frame(img_resized, wide = "c")
setDT(dt_img)
dt_img[, c.4:=NULL] # while its Jpg I want to keep the template as is
setnames(dt_img, c("c.1", "c.2", "c.3"), c("R", "G", "B"))


# Plotting the original resized pixels
plot_ly(data = dt_img,
        x = ~x,
        y = ~y,
        type = "scattergl",
        mode = "markers",
        marker = list(color = ~rgb(R, G, B))) |>
  layout(yaxis = list(autorange = "reversed", scaleanchor = "x", scaleratio = 1))


# --- 4. Exploratory Data Analysis (Clustering Prep) --- #
dt_rgb <- dt_img[, .(R, G, B)]

# How many unique colors?
dt_rgb[,.N,.(R,G,B)][order(N)]
uniqueN(dt_rgb[,.(R,G,B)]) # 13038 unique colors


# --- 5. PCA Analysis --- #
pca <- prcomp(dt_rgb, scale = TRUE)
summary(pca)
# This tells us how high the K will be to some extent. 
# PC1 is very high, which means most colors can be explained by one main variance grouping.


# Visualizing PCA Variance via Heatmaps
vars <- get_pca_var(pca)
plot_ly(x = colnames(vars$cos2), y = row.names(vars$cos2), z = vars$cos2, type = "heatmap", colors = "Reds")
plot_ly(x = colnames(vars$contrib), y = row.names(vars$contrib), z = vars$contrib, type = "heatmap", colors = "Reds")



# 3D PCA Visualization
# 1. Get the center of the data
avg <- colMeans(dt_img[, .(R, G, B)])

# 2. Create the endpoints for the 3 "Fields" (Lines)
line1 <- rbind(avg, avg + (pca$rotation[,1] * 0.8)) # PC1 (Longest)
line2 <- rbind(avg, avg + (pca$rotation[,2] * 0.4)) # PC2 (Medium)
line3 <- rbind(avg, avg + (pca$rotation[,3] * 0.2)) # PC3 (Shortest)

# 3. Build the plot layer by layer
plot_ly() |>
  # Layer 1: The Pixels (The "Cloud")
  add_markers(data = dt_img, x = ~R, y = ~G, z = ~B, 
              marker = list(size = 1, opacity = 0.1), name = "Pixels") |>
  # Layer 2: The PC1 Field (The "Brightness" Axis)
  add_paths(x = line1[,1], y = line1[,2], z = line1[,3], 
            line = list(color = "black", width = 10), name = "PC1 (95%)") |>
  # Layer 3: The PC2 Field (The "Color" Axis)
  add_paths(x = line2[,1], y = line2[,2], z = line2[,3], 
            line = list(color = "yellow", width = 10), name = "PC2 (4.6%)") |>
  # Layer 4: The PC3 Field (The "Noise" Axis)
  add_paths(x = line3[,1], y = line3[,2], z = line3[,3], 
            line = list(color = "green", width = 10), name = "PC3 (0.2%)")




# --- 6. Choosing K (Elbow Method) --- #
# Testing multiple k values
cls <- data.table(k = seq(8, 20, 2), WSS = 0)

for (i in cls[, k]) {
  cl <- kmeans(dt_rgb, centers = i, nstart = 100)
  cls[k == i, WSS := cl$tot.withinss]
}

plot_ly(data = cls, type = "scatter", mode = "lines") |>
  add_trace(x = ~k, y = ~WSS, name = "WSS")

# K-Selection Thought Process:
# I wasn't certain how this would work. First I looked at the elbow from 2-40, and zoomed into 2-10 
# because I saw the largest angles there. After redoing it from 2-10, I noticed 3 and 4 mathematically  
# looked best, but the visual output looked very bad. 
# Because of that, I counted the main colors and shadows by hand and got 11. I then ran a new search  
# slightly below and well above that range (8-20). In that plot, there is a gradual slowing in the angles, 
# but K=16 suddenly had a snap, so I chose 16 as my final result.



# --- 7. Final Clusters & Image Reconstruction --- #
km <- kmeans(dt_rgb, centers = 16, nstart = 100)

# Map original pixels to their new cluster center colors
dt_newimg <- data.table(
  x = dt_img[, x],
  y = dt_img[, y],
  R = km$centers[km$cluster, "R"],
  G = km$centers[km$cluster, "G"],
  B = km$centers[km$cluster, "B"]
)

# Plot final quantized image
plot_ly(data = dt_newimg,
        x = ~x,
        y = ~y,
        type = "scattergl",
        mode = "markers",
        marker = list(color = ~rgb(R, G, B))) |>
  layout(yaxis = list(autorange = "reversed", scaleanchor = "x", scaleratio = 1))

# Final 2D PCA cluster visualization
fviz_cluster(km, data = dt_rgb) # Since there are 3 dims (RGB), it automatically uses PCA